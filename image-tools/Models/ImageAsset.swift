import Foundation
import AppKit
import UniformTypeIdentifiers

struct ImageAsset: Identifiable, Hashable {
    let id: UUID
    var originalURL: URL
    var workingURL: URL
    var thumbnail: NSImage?
    var isEdited: Bool
    var isEnabled: Bool
    var backupURL: URL?

    // Metadata
    var originalPixelSize: CGSize?
    var originalFileSizeBytes: Int?

    init(url: URL) {
        self.id = UUID()
        self.originalURL = url
        self.workingURL = url
        self.thumbnail = ThumbnailGenerator.generateThumbnail(for: url)
        self.isEdited = false
        self.isEnabled = true
        self.backupURL = nil
        if let img = NSImage(contentsOf: url) { self.originalPixelSize = img.size } else { self.originalPixelSize = nil }
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path), let size = attrs[.size] as? NSNumber { self.originalFileSizeBytes = size.intValue } else { self.originalFileSizeBytes = nil }
    }
}

enum ImageFormat: String, CaseIterable, Identifiable {
    case jpeg
    case png
    case heic
    case tiff
    case bmp
    case gif
    case webp // best effort via Core Image if supported on platform

    var id: String { rawValue }

    var displayName: String {
        rawValue.uppercased()
    }

    var utType: UTType {
        switch self {
        case .jpeg: return .jpeg
        case .png: return .png
        case .heic: return .heic
        case .tiff: return .tiff
        case .bmp: return .bmp
        case .gif: return .gif
        case .webp:
            if let webp = UTType("org.webmproject.webp") { return webp }
            return .png
        }
    }

    var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .png: return "png"
        case .heic: return "heic"
        case .tiff: return "tiff"
        case .bmp: return "bmp"
        case .gif: return "gif"
        case .webp: return "webp"
        }
    }
}

enum SizeUnitToggle {
    case percent
    case pixels
}

enum CompressionModeToggle {
    case percent
    case targetKB
}

enum HorizontalVertical: String {
    case horizontal
    case vertical
}

enum ImageRotation: Int, CaseIterable, Identifiable {
    case r0 = 0, r90 = 90, r180 = 180, r270 = 270
    var id: Int { rawValue }
}

struct ThumbnailGenerator {
    static func generateThumbnail(for url: URL, maxSize: CGFloat = 128) -> NSImage? {
        guard let img = NSImage(contentsOf: url) else { return nil }
        let longest = max(img.size.width, img.size.height)
        guard longest > 0 else { return img }
        let ratio = maxSize / longest
        let newSize = NSSize(width: img.size.width * ratio, height: img.size.height * ratio)
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        img.draw(in: NSRect(origin: .zero, size: newSize), from: .zero, operation: .copy, fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }
} 