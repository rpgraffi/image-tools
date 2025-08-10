import Foundation
import CoreImage
import AppKit
import UniformTypeIdentifiers
import ImageIO

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
        // Normalize orientation to 'up' so rendered pixels aren't rotated again on subsequent loads
        props[kCGImagePropertyOrientation] = 1
        if var tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            tiff[kCGImagePropertyTIFFOrientation] = 1
            props[kCGImagePropertyTIFFDictionary] = tiff
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