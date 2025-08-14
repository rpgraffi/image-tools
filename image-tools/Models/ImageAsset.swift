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

struct ImageFormat: Identifiable, Hashable, Equatable {
    let utType: UTType

    var id: String { utType.identifier }

    var displayName: String {
        let ext = preferredFilenameExtension
        if !ext.isEmpty && ext != "img" { return ext.uppercased() }
        let id = utType.identifier
        if let last = id.split(separator: ".").last, last.count <= 8 {
            return last.uppercased()
        }
        return (utType.localizedDescription ?? id).uppercased()
    }

    var preferredFilenameExtension: String {
        ImageIOCapabilities.shared.preferredFilenameExtension(for: utType)
    }

    var fullName: String {
        utType.localizedDescription ?? utType.identifier
    }
}

struct FormatCapabilities {
    let isReadable: Bool
    let isWritable: Bool
    let supportsLossless: Bool
    let supportsQuality: Bool
    let supportsMetadata: Bool
    let supportsAlpha: Bool
    let resizeRestricted: Bool
}

enum SizeUnitToggle {
    case percent
    case pixels
}

enum HorizontalVertical: String {
    case horizontal
    case vertical
}

enum ImageRotation: Int, CaseIterable, Identifiable {
    case r0 = 0, r90 = 90, r180 = 180, r270 = 270
    var id: Int { rawValue }
}

