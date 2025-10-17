import Foundation
import ImageIO

struct ImageMetadata {
    static func pixelSize(for url: URL) -> CGSize? {
        if let src = CGImageSourceCreateWithURL(url as CFURL, nil),
           let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
           let wNum = props[kCGImagePropertyPixelWidth] as? NSNumber,
           let hNum = props[kCGImagePropertyPixelHeight] as? NSNumber {
            return CGSize(width: CGFloat(truncating: wNum), height: CGFloat(truncating: hNum))
        }
        return nil
    }

    static func fileSizeBytes(for url: URL) -> Int? {
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? NSNumber {
            return size.intValue
        }
        return nil
    }
}


