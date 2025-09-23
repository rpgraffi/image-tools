import AppKit
import ImageIO

struct ThumbnailGenerator {
    static func generateThumbnail(for url: URL, maxPixelSize: CGFloat = 256) -> NSImage? {
        // Avoid touching AppKit screen APIs off the main thread to prevent QoS inversions
        let scale: CGFloat
        if Thread.isMainThread, let s = NSScreen.main?.backingScaleFactor {
            scale = s
        } else {
            scale = 2.0
        }
        let pixelMax = max(1, Int(maxPixelSize * scale))

        let sourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]

        if let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary) {
            let thumbOptions: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: pixelMax,
                kCGImageSourceShouldCacheImmediately: true
            ]

            if let cgThumb = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) {
                let size = NSSize(width: CGFloat(cgThumb.width) / scale, height: CGFloat(cgThumb.height) / scale)
                return NSImage(cgImage: cgThumb, size: size)
            }
        }

        return fallbackThumbnail(for: url, maxPixelSize: maxPixelSize)
    }

    private static func fallbackThumbnail(for url: URL, maxPixelSize: CGFloat) -> NSImage? {
        guard let img = NSImage(contentsOf: url) else { return nil }
        let longest = max(img.size.width, img.size.height)
        guard longest > 0 else { return img }
        let ratio = maxPixelSize / longest
        let newSize = NSSize(width: img.size.width * ratio, height: img.size.height * ratio)
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        img.draw(in: NSRect(origin: .zero, size: newSize), from: .zero, operation: .copy, fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }
} 