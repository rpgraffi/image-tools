import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import AppKit
import UniformTypeIdentifiers
import ImageIO
import Vision

enum ImageOperationError: Error {
    case loadFailed
    case exportFailed
    case backgroundRemovalUnavailable
    case permissionDenied
}

protocol ImageOperation {
    func transformed(_ input: CIImage) throws -> CIImage
}

// Load a CIImage while applying EXIF/TIFF orientation so pixels are normalized to 'up'
func loadCIImageApplyingOrientation(from url: URL) throws -> CIImage {
    let options: [CIImageOption: Any] = [
        .applyOrientationProperty: true
    ]
    if let ci = CIImage(contentsOf: url, options: options) { return ci }
    throw ImageOperationError.loadFailed
}

struct ResizeOperation: ImageOperation {
    enum Mode { case percent(Double); case pixels(width: Int?, height: Int?) }
    let mode: Mode

    // Reusable pixel transform for in-memory pipelines
    func transformed(_ input: CIImage) throws -> CIImage {
        let originalExtent = input.extent
        let targetSize: CGSize = {
            let inputMode: ResizeInput = {
                switch mode {
                case .percent(let p): return .percent(p)
                case .pixels(let width, let height): return .pixels(width: width, height: height)
                }
            }()
            // Processing should not upscale either.
            return ResizeMath.targetSize(for: originalExtent.size, input: inputMode, noUpscale: true)
        }()

        let scaleX = targetSize.width / originalExtent.width
        let scaleY = targetSize.height / originalExtent.height
        let lanczos = CIFilter.lanczosScaleTransform()
        lanczos.inputImage = input
        lanczos.scale = Float(min(scaleX, scaleY))
        lanczos.aspectRatio = Float(scaleX / scaleY)
        guard let output = lanczos.outputImage else { throw ImageOperationError.exportFailed }
        return output
    }

    // Disk write handled at pipeline end
}

/// Ensures the image matches the size restrictions of a target format by resizing when necessary.
/// Typically injected by the pipeline right before conversion for constrained formats.
struct ConstrainSizeOperation: ImageOperation {
    let targetFormat: ImageFormat

    // Reusable pixel transform for in-memory pipelines
    func transformed(_ input: CIImage) throws -> CIImage {
        let caps = ImageIOCapabilities.shared
        guard let _ = caps.sizeRestrictions(forUTType: targetFormat.utType) else {
            return input
        }
        let current = input.extent.size
        if caps.isValidPixelSize(current, for: targetFormat.utType) {
            return input
        }
        guard let side = caps.suggestedSquareSide(for: targetFormat.utType, source: current) else {
            return input
        }
        let target = CGSize(width: side, height: side)
        let scaleX = target.width / current.width
        let scaleY = target.height / current.height
        let lanczos = CIFilter.lanczosScaleTransform()
        lanczos.inputImage = input
        lanczos.scale = Float(min(scaleX, scaleY))
        lanczos.aspectRatio = Float(scaleX / scaleY)
        guard let output = lanczos.outputImage else { throw ImageOperationError.exportFailed }
        return output
    }

    // Disk write handled at pipeline end
}


struct FlipVerticalOperation: ImageOperation {
    // Reusable pixel transform for in-memory pipelines
    // Flips along the vertical axis (creates a horizontal mirror / left-to-right flip)
    func transformed(_ input: CIImage) throws -> CIImage {
        let extent = input.extent
        let transform = CGAffineTransform(scaleX: -1, y: 1).translatedBy(x: -extent.width, y: 0)
        return input.transformed(by: transform)
    }
    // Disk write handled at pipeline end
}

struct CropOperation: ImageOperation {
    let targetWidth: Int
    let targetHeight: Int
    
    // Resize to cover target dimensions, then center crop to exact size
    func transformed(_ input: CIImage) throws -> CIImage {
        let extent = input.extent
        let currentWidth = extent.width
        let currentHeight = extent.height
        
        let targetW = CGFloat(targetWidth)
        let targetH = CGFloat(targetHeight)
        
        // Calculate scale to COVER the target dimensions (not fit within)
        let scaleX = targetW / currentWidth
        let scaleY = targetH / currentHeight
        let scale = max(scaleX, scaleY) // Use max to cover, not min to fit
        
        // Resize to cover the target dimensions
        let lanczos = CIFilter.lanczosScaleTransform()
        lanczos.inputImage = input
        lanczos.scale = Float(scale)
        lanczos.aspectRatio = 1.0
        guard let scaled = lanczos.outputImage else { throw ImageOperationError.exportFailed }
        
        let scaledExtent = scaled.extent
        
        // Now center crop to exact target dimensions
        // Round x and y to avoid sub-pixel positioning that can cause off-by-one errors
        let x = ((scaledExtent.width - targetW) / 2).rounded(.toNearestOrEven)
        let y = ((scaledExtent.height - targetH) / 2).rounded(.toNearestOrEven)
        
        let cropRect = CGRect(x: x, y: y, width: targetW, height: targetH)
        return scaled.cropped(to: cropRect)
    }
}

struct RemoveBackgroundOperation: ImageOperation {
    func transformed(_ input: CIImage) throws -> CIImage {
        guard let masked = try? removeBackgroundCIImage(input) else {
            throw ImageOperationError.backgroundRemovalUnavailable
        }
        return masked
    }
}

// MARK: - Foreground/background masking helpers

func generateForegroundMaskCIImage(for inputImage: CIImage) throws -> CIImage {
    let handler = VNImageRequestHandler(ciImage: inputImage)
    let request = VNGenerateForegroundInstanceMaskRequest()
    do {
        try handler.perform([request])
    } catch {
        throw ImageOperationError.backgroundRemovalUnavailable
    }
    guard let result = request.results?.first else {
        throw ImageOperationError.backgroundRemovalUnavailable
    }
    do {
        let maskPixelBuffer = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
        return CIImage(cvPixelBuffer: maskPixelBuffer)
    } catch {
        throw ImageOperationError.backgroundRemovalUnavailable
    }
}

func removeBackgroundCIImage(_ inputImage: CIImage) throws -> CIImage {
    let mask = try generateForegroundMaskCIImage(for: inputImage)
    let filter = CIFilter.blendWithMask()
    filter.inputImage = inputImage
    filter.maskImage = mask
    filter.backgroundImage = CIImage.empty()
    guard let output = filter.outputImage else { throw ImageOperationError.exportFailed }
    return output
}
