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

struct ResizeOperation: ImageOperation {
    enum Mode { case percent(Double); case pixels(width: Int?, height: Int?) }
    let mode: Mode

    func apply(to url: URL) throws -> URL {
        guard let ciImage = CIImage(contentsOf: url) else { throw ImageOperationError.loadFailed }
        let originalExtent = ciImage.extent
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
        lanczos.inputImage = ciImage
        lanczos.scale = Float(min(scaleX, scaleY))
        lanczos.aspectRatio = Float(scaleX / scaleY)
        guard let output = lanczos.outputImage else { throw ImageOperationError.exportFailed }

        return try ImageExporter.export(ciImage: output, originalURL: url, format: nil, compressionQuality: nil)
    }
}

struct ConvertOperation: ImageOperation {
    let format: ImageFormat
    func apply(to url: URL) throws -> URL {
        guard let ciImage = CIImage(contentsOf: url) else { throw ImageOperationError.loadFailed }
        return try ImageExporter.export(ciImage: ciImage, originalURL: url, format: format, compressionQuality: nil)
    }
}

struct CompressOperation: ImageOperation {
    enum Mode { case percent(Double); case targetKB(Int) }
    let mode: Mode
    let formatHint: ImageFormat? // to guide lossy export like JPEG/HEIC

    func apply(to url: URL) throws -> URL {
        guard let ciImage = CIImage(contentsOf: url) else { throw ImageOperationError.loadFailed }
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
    func apply(to url: URL) throws -> URL {
        let angle = Double(rotation.rawValue) * Double.pi / 180.0
        guard let ciImage = CIImage(contentsOf: url) else { throw ImageOperationError.loadFailed }
        let transform = CGAffineTransform(rotationAngle: angle)
        let output = ciImage.transformed(by: transform)
        return try ImageExporter.export(ciImage: output, originalURL: url, format: nil, compressionQuality: nil)
    }
}

struct FlipOperation: ImageOperation {
    let direction: HorizontalVertical
    func apply(to url: URL) throws -> URL {
        guard let ciImage = CIImage(contentsOf: url) else { throw ImageOperationError.loadFailed }
        let extent = ciImage.extent
        let transform: CGAffineTransform
        switch direction {
        case .horizontal:
            transform = CGAffineTransform(scaleX: -1, y: 1).translatedBy(x: -extent.width, y: 0)
        case .vertical:
            transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -extent.height)
        }
        let output = ciImage.transformed(by: transform)
        return try ImageExporter.export(ciImage: output, originalURL: url, format: nil, compressionQuality: nil)
    }
}

struct RemoveBackgroundOperation: ImageOperation {
    func apply(to url: URL) throws -> URL {
        guard let ciImage = CIImage(contentsOf: url) else { throw ImageOperationError.loadFailed }
        return try ImageExporter.export(ciImage: ciImage, originalURL: url, format: nil, compressionQuality: nil)
    }
}

struct ImageExporter {
    static func export(ciImage: CIImage, originalURL: URL, format: ImageFormat?, compressionQuality: Double?, stripMetadata: Bool = false) throws -> URL {
        // Decide format and UTType, honoring platform capabilities
        let requestedFormat: ImageFormat = format ?? (inferFormat(from: originalURL) ?? ImageIOCapabilities.shared.format(forIdentifier: UTType.png.identifier)!)
        let requestedUTI: UTType = requestedFormat.utType

        // Fallback chain: requested -> PNG -> JPEG
        let caps = ImageIOCapabilities.shared
        let actualUTI: UTType = {
            if caps.supportsWriting(utType: requestedUTI) { return requestedUTI }
            if caps.supportsWriting(utType: .png) { return .png }
            return .jpeg
        }()

        let ciContext = CIContext()
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent, format: .RGBA8, colorSpace: colorSpace) else {
            throw ImageOperationError.exportFailed
        }

        let tempDir = FileManager.default.temporaryDirectory
        let ext = ImageIOCapabilities.shared.preferredFilenameExtension(for: actualUTI)
        let base = originalURL.deletingPathExtension().lastPathComponent
        let tempFilename = base + "_tmp_" + String(UUID().uuidString.prefix(8)) + "." + ext
        let outputURL = tempDir.appendingPathComponent(tempFilename)

        guard let dest = CGImageDestinationCreateWithURL(outputURL as CFURL, actualUTI.identifier as CFString, 1, nil) else {
            throw ImageOperationError.exportFailed
        }

        var props: [CFString: Any] = [:]
        if !stripMetadata {
            if let src = CGImageSourceCreateWithURL(originalURL as CFURL, nil),
               let meta = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] {
                for (k, v) in meta { props[k] = v }
            }
        }
        if actualUTI == .jpeg || actualUTI == UTType.heic {
            props[kCGImageDestinationLossyCompressionQuality] = compressionQuality ?? 0.9
        }
        CGImageDestinationAddImage(dest, cgImage, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw ImageOperationError.exportFailed }
        return outputURL
    }

    static func inferFormat(from url: URL) -> ImageFormat? {
        return ImageIOCapabilities.shared.formatForURL(url)
    }
} 