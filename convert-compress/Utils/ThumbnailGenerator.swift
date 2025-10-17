import AppKit
import ImageIO

struct ThumbnailGenerator {
    struct Output: Sendable {
        let thumbnail: NSImage?
        let pixelSize: CGSize?
        let fileSizeBytes: Int?
    }

    static func load(for url: URL, maxPixelSize: CGFloat = 256) async -> Output {
        ImageToolsViewModel.ingestionLogger.debug("Loading thumbnail: \(url.lastPathComponent, privacy: .public)")
        
        let standardizedURL = url.standardizedFileURL
        let scale = await MainActor.run { NSScreen.main?.backingScaleFactor ?? 2.0 }
        let pixelMax = max(1, Int(maxPixelSize * scale))

        var pixelSize: CGSize?
        var thumbnail: NSImage?

        let fileSizeBytes = try? standardizedURL.resourceValues(forKeys: [.fileSizeKey]).fileSize

        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(standardizedURL as CFURL, sourceOptions as CFDictionary) else {
            return Output(thumbnail: nil, pixelSize: nil, fileSizeBytes: fileSizeBytes)
        }

        if let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
           let w = props[kCGImagePropertyPixelWidth] as? NSNumber,
           let h = props[kCGImagePropertyPixelHeight] as? NSNumber {
            pixelSize = CGSize(width: CGFloat(truncating: w), height: CGFloat(truncating: h))
        }

        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: pixelMax,
            kCGImageSourceShouldCacheImmediately: true
        ]

        if let cgThumb = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) {
            let size = NSSize(width: CGFloat(cgThumb.width) / scale, height: CGFloat(cgThumb.height) / scale)
            thumbnail = NSImage(cgImage: cgThumb, size: size)
        }

        return Output(thumbnail: thumbnail, pixelSize: pixelSize, fileSizeBytes: fileSizeBytes)
    }
}