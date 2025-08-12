import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import AppKit
import UniformTypeIdentifiers
import ImageIO

enum ImageOperationError: Error {
    case loadFailed
    case exportFailed
    case backgroundRemovalUnavailable
}

protocol ImageOperation {
    func apply(to url: URL) throws -> URL
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
        let targetSize: CGSize
        switch mode {
        case .percent(let p):
            let scale = max(p, 0.01)
            targetSize = CGSize(width: originalExtent.width * scale, height: originalExtent.height * scale)
        case .pixels(let width, let height):
            let w = CGFloat(width ?? Int(originalExtent.width))
            let h = CGFloat(height ?? Int(originalExtent.height))
            targetSize = CGSize(width: max(w, 1), height: max(h, 1))
        }

        let scaleX = targetSize.width / originalExtent.width
        let scaleY = targetSize.height / originalExtent.height
        let lanczos = CIFilter.lanczosScaleTransform()
        lanczos.inputImage = input
        lanczos.scale = Float(min(scaleX, scaleY))
        lanczos.aspectRatio = Float(scaleX / scaleY)
        guard let output = lanczos.outputImage else { throw ImageOperationError.exportFailed }
        return output
    }

    func apply(to url: URL) throws -> URL {
        guard let ciImage = try? loadCIImageApplyingOrientation(from: url) else { throw ImageOperationError.loadFailed }
        let output = try transformed(ciImage)
        return try ImageExporter.export(ciImage: output, originalURL: url, format: nil, compressionQuality: nil)
    }
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

    func apply(to url: URL) throws -> URL {
        guard let ciImage = try? loadCIImageApplyingOrientation(from: url) else {
            throw ImageOperationError.loadFailed
        }
        let output = try transformed(ciImage)
        return try ImageExporter.export(ciImage: output, originalURL: url, format: nil, compressionQuality: nil)
    }
}

struct ConvertOperation: ImageOperation {
    let format: ImageFormat
    func apply(to url: URL) throws -> URL {
        let ciImage = try loadCIImageApplyingOrientation(from: url)
        return try ImageExporter.export(ciImage: ciImage, originalURL: url, format: format, compressionQuality: nil)
    }
}

struct CompressOperation: ImageOperation {
    enum Mode { case percent(Double); case targetKB(Int) }
    let mode: Mode
    let formatHint: ImageFormat? // to guide lossy export like JPEG/HEIC

    func apply(to url: URL) throws -> URL {
        let ciImage = try loadCIImageApplyingOrientation(from: url)
        switch mode {
        case .percent(let p):
            let q = max(min(p, 1.0), 0.01)
            return try ImageExporter.export(ciImage: ciImage, originalURL: url, format: formatHint, compressionQuality: q)
        case .targetKB(let kb):
            let targetBytes = max(kb, 1) * 1024
            var quality: Double = 0.9
            var bestURL: URL = url
            // simple binary-like search iterations
            var low: Double = 0.05
            var high: Double = 0.95
            for _ in 0..<8 {
                let tmpURL = try ImageExporter.export(ciImage: ciImage, originalURL: url, format: formatHint, compressionQuality: quality)
                let size = (try? FileManager.default.attributesOfItem(atPath: tmpURL.path)[.size] as? NSNumber)?.intValue ?? 0
                if size > targetBytes {
                    high = quality
                    quality = (low + quality) / 2
                } else {
                    bestURL = tmpURL
                    low = quality
                    quality = (quality + high) / 2
                }
            }
            return bestURL
        }
    }
}

struct RotateOperation: ImageOperation {
    let rotation: ImageRotation
    // Reusable pixel transform for in-memory pipelines
    func transformed(_ input: CIImage) throws -> CIImage {
        let angle = Double(rotation.rawValue) * Double.pi / 180.0
        let transform = CGAffineTransform(rotationAngle: angle)
        return input.transformed(by: transform)
    }
    func apply(to url: URL) throws -> URL {
        let ciImage = try loadCIImageApplyingOrientation(from: url)
        let output = try transformed(ciImage)
        return try ImageExporter.export(ciImage: output, originalURL: url, format: nil, compressionQuality: nil)
    }
}

struct FlipOperation: ImageOperation {
    let direction: HorizontalVertical
    // Reusable pixel transform for in-memory pipelines
    func transformed(_ input: CIImage) throws -> CIImage {
        let extent = input.extent
        let transform: CGAffineTransform
        switch direction {
        case .horizontal:
            transform = CGAffineTransform(scaleX: -1, y: 1).translatedBy(x: -extent.width, y: 0)
        case .vertical:
            transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -extent.height)
        }
        return input.transformed(by: transform)
    }
    func apply(to url: URL) throws -> URL {
        let ciImage = try loadCIImageApplyingOrientation(from: url)
        let output = try transformed(ciImage)
        return try ImageExporter.export(ciImage: output, originalURL: url, format: nil, compressionQuality: nil)
    }
}

struct RemoveBackgroundOperation: ImageOperation {
    func apply(to url: URL) throws -> URL {
        let ciImage = try loadCIImageApplyingOrientation(from: url)
        return try ImageExporter.export(ciImage: ciImage, originalURL: url, format: nil, compressionQuality: nil)
    }
}

 