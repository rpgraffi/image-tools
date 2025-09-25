@preconcurrency import AppKit
import ImageIO

actor ThumbnailGenerator {
    struct Output: Sendable {
        let thumbnail: NSImage?
        let pixelSize: CGSize?
        let fileSizeBytes: Int?
    }

    static let shared = ThumbnailGenerator()

    private final class CacheEntry: NSObject {
        let output: Output
        init(_ output: Output) { self.output = output }
    }

    private let cache = NSCache<NSURL, CacheEntry>()
    private var inflight: [NSURL: Task<Output, Never>] = [:]

    func load(for url: URL, maxPixelSize: CGFloat = 256) async -> Output {
        let key = url.standardizedFileURL as NSURL

        if let cached = cache.object(forKey: key) {
            return cached.output
        }

        if let existing = inflight[key] {
            return await existing.value
        }

        let task = Task(priority: .userInitiated) {
            await ThumbnailGenerator.makeOutput(for: url, maxPixelSize: maxPixelSize)
        }
        inflight[key] = task

        let result = await task.value
        inflight[key] = nil
        cache.setObject(CacheEntry(result), forKey: key)
        return result
    }

    func cachedThumbnail(for url: URL) -> NSImage? {
        let key = url.standardizedFileURL as NSURL
        return cache.object(forKey: key)?.output.thumbnail
    }

    private static func makeOutput(for url: URL, maxPixelSize: CGFloat) async -> Output {
        let standardizedURL = url.standardizedFileURL
        let scale = await preferredScale()
        let pixelMax = max(1, Int(maxPixelSize * scale))

        var pixelSize: CGSize? = nil
        var thumbnail: NSImage? = nil

        let fileSizeBytes: Int? = {
            if let values = try? standardizedURL.resourceValues(forKeys: [.fileSizeKey]),
               let size = values.fileSize {
                return size
            }
            return nil
        }()

        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        if let source = CGImageSourceCreateWithURL(standardizedURL as CFURL, sourceOptions as CFDictionary) {
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
        }

        if thumbnail == nil {
            if let fallback = await fallbackThumbnail(for: standardizedURL, maxPixelSize: maxPixelSize) {
                thumbnail = fallback.image
                if pixelSize == nil { pixelSize = fallback.originalPixelSize }
            }
        }

        return Output(thumbnail: thumbnail, pixelSize: pixelSize, fileSizeBytes: fileSizeBytes)
    }

    private struct FallbackResult {
        let image: NSImage
        let originalPixelSize: CGSize
    }

    @MainActor
    private static func fallbackThumbnail(for url: URL, maxPixelSize: CGFloat) -> FallbackResult? {
        guard let img = NSImage(contentsOf: url) else { return nil }
        let originalSize = img.size
        let longest = max(originalSize.width, originalSize.height)
        guard longest > 0 else { return FallbackResult(image: img, originalPixelSize: originalSize) }
        let ratio = min(1, maxPixelSize / longest)
        let newSize = NSSize(width: originalSize.width * ratio, height: originalSize.height * ratio)
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        img.draw(in: NSRect(origin: .zero, size: newSize), from: .zero, operation: .copy, fraction: 1.0)
        newImage.unlockFocus()
        return FallbackResult(image: newImage, originalPixelSize: originalSize)
    }

    @MainActor
    private static func preferredScale() -> CGFloat {
        NSScreen.main?.backingScaleFactor ?? 2.0
    }
}