import Foundation
import CoreImage
import AppKit
import UniformTypeIdentifiers
import ImageIO

struct ImageExporter {
    private static let sharedCIContext: CIContext = {
        CIContext()
    }()
    // MARK: - DRY helpers
    private static func decideActualUTType(originalURL: URL, requestedFormat: ImageFormat?) -> UTType {
        let requestedFormat: ImageFormat = requestedFormat ?? (inferFormat(from: originalURL) ?? ImageIOCapabilities.shared.format(forIdentifier: UTType.png.identifier)!)
        let requestedUTI: UTType = requestedFormat.utType
        let caps = ImageIOCapabilities.shared
        if caps.supportsWriting(utType: requestedUTI) { return requestedUTI }
        if caps.supportsWriting(utType: .png) { return .png }
        return .jpeg
    }

    // Exposed helper for planning destination names without doing any encode work
    static func decideUTTypeForExport(originalURL: URL, requestedFormat: ImageFormat?) -> UTType {
        return decideActualUTType(originalURL: originalURL, requestedFormat: requestedFormat)
    }

    private static func buildDestinationProperties(originalURL: URL, actualUTI: UTType, compressionQuality: Double?, stripMetadata: Bool) -> [CFString: Any] {
        var props: [CFString: Any] = [:]
        if !stripMetadata {
            if let src = CGImageSourceCreateWithURL(originalURL as CFURL, nil),
               let meta = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] {
                for (k, v) in meta { props[k] = v }
            }
        }
        props[kCGImagePropertyOrientation] = 1
        if var tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            tiff[kCGImagePropertyTIFFOrientation] = 1
            props[kCGImagePropertyTIFFDictionary] = tiff
        }
        if actualUTI == .jpeg || actualUTI == UTType.heic {
            props[kCGImageDestinationLossyCompressionQuality] = compressionQuality ?? 0.9
        }
        return props
    }

    static func encodeToData(ciImage: CIImage, originalURL: URL, format: ImageFormat?, compressionQuality: Double?, stripMetadata: Bool = false) throws -> (data: Data, uti: UTType) {
        let actualUTI = decideActualUTType(originalURL: originalURL, requestedFormat: format)
        let ciContext = ImageExporter.sharedCIContext
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent, format: .RGBA8, colorSpace: colorSpace) else {
            throw ImageOperationError.exportFailed
        }

        // Custom encoder if available for this UTType
        if let encoder = CustomImageEncoderRegistry.encoder(for: actualUTI) {
            let size = CGSize(width: ciImage.extent.width, height: ciImage.extent.height)
            let data = try encoder.encode(cgImage: cgImage, pixelSize: size, utType: actualUTI, compressionQuality: compressionQuality, stripMetadata: stripMetadata)
            return (data, actualUTI)
        }

        // Default path: ImageIO
        let props = buildDestinationProperties(originalURL: originalURL, actualUTI: actualUTI, compressionQuality: compressionQuality, stripMetadata: stripMetadata)
        let cfData = CFDataCreateMutable(nil, 0)!
        guard let dest = CGImageDestinationCreateWithData(cfData, actualUTI.identifier as CFString, 1, nil) else {
            throw ImageOperationError.exportFailed
        }
        CGImageDestinationAddImage(dest, cgImage, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw ImageOperationError.exportFailed }
        let data = cfData as Data
        return (data, actualUTI)
    }

    static func export(ciImage: CIImage, originalURL: URL, format: ImageFormat?, compressionQuality: Double?, stripMetadata: Bool = false) throws -> URL {
        let result = try encodeToData(ciImage: ciImage, originalURL: originalURL, format: format, compressionQuality: compressionQuality, stripMetadata: stripMetadata)

        let tempDir = FileManager.default.temporaryDirectory
        let ext = ImageIOCapabilities.shared.preferredFilenameExtension(for: result.uti)
        let base = originalURL.deletingPathExtension().lastPathComponent
        let tempFilename = base + "_tmp_" + String(UUID().uuidString.prefix(8)) + "." + ext
        let outputURL = tempDir.appendingPathComponent(tempFilename)
        try result.data.write(to: outputURL, options: [.atomic])
        return outputURL
    }

    static func inferFormat(from url: URL) -> ImageFormat? {
        return ImageIOCapabilities.shared.formatForURL(url)
    }
} 