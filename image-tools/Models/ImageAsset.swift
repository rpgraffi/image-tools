import Foundation
import AppKit
import UniformTypeIdentifiers

struct ImageAsset: Identifiable, Hashable {
    let id: UUID
    var originalURL: URL
    var workingURL: URL
    var thumbnail: NSImage?
    var isEdited: Bool
    var backupURL: URL?

    // Metadata
    var originalPixelSize: CGSize?
    var originalFileSizeBytes: Int?

    init(url: URL) {
        self.id = UUID()
        self.originalURL = url.standardizedFileURL
        self.workingURL = url.standardizedFileURL
        self.thumbnail = nil
        self.isEdited = false
        self.backupURL = nil
        self.originalPixelSize = nil
        self.originalFileSizeBytes = nil
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

enum ResizeMode {
    case resize
    case crop
}

