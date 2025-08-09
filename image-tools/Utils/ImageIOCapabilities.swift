import Foundation
import UniformTypeIdentifiers
import ImageIO

final class ImageIOCapabilities {
    static let shared = ImageIOCapabilities()

    private let readableTypes: Set<String>
    private let writableTypes: Set<String>

    private init() {
        if let readIds = CGImageSourceCopyTypeIdentifiers() as? [String] {
            self.readableTypes = Set(readIds)
        } else {
            self.readableTypes = []
        }
        if let writeIds = CGImageDestinationCopyTypeIdentifiers() as? [String] {
            self.writableTypes = Set(writeIds)
        } else {
            self.writableTypes = []
        }
    }

    func supportsWriting(utType: UTType) -> Bool {
        writableTypes.contains(utType.identifier)
    }

    func supportsReading(utType: UTType) -> Bool {
        readableTypes.contains(utType.identifier)
    }

    func preferredFilenameExtension(for utType: UTType) -> String {
        if utType == .jpeg { return "jpg" }
        return utType.preferredFilenameExtension ?? "img"
    }

    // MARK: - Dynamic format lists
    func readableFormats() -> [ImageFormat] {
        allImageFormats().filter { supportsReading(utType: $0.utType) }
    }

    func writableFormats() -> [ImageFormat] {
        allImageFormats().filter { supportsWriting(utType: $0.utType) }
    }

    func allImageFormats() -> [ImageFormat] {
        let union = readableTypes.union(writableTypes)
        var results: [ImageFormat] = []
        for id in union {
            if let t = UTType(id), t.conforms(to: .image) {
                results.append(ImageFormat(utType: t))
            }
        }
        // Ensure some common types appear first in a stable, human-friendly order
        let priority: [String: Int] = [
            UTType.jpeg.identifier: 0,
            UTType.png.identifier: 1,
            UTType.heic.identifier: 2,
            UTType.tiff.identifier: 3,
            UTType.bmp.identifier: 4,
            UTType.gif.identifier: 5
        ]
        return results.sorted { a, b in
            let ai = priority[a.utType.identifier] ?? Int.max
            let bi = priority[b.utType.identifier] ?? Int.max
            if ai != bi { return ai < bi }
            return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
        }
    }

    // MARK: - Capabilities
    func capabilities(for format: ImageFormat) -> FormatCapabilities {
        capabilities(forUTType: format.utType)
    }

    func capabilities(forUTType utType: UTType) -> FormatCapabilities {
        let isReadable = supportsReading(utType: utType)
        let isWritable = supportsWriting(utType: utType)
        let supportsQuality = (utType == .jpeg) || (utType == UTType.heic)
        let supportsLossless = (utType == .png) || (utType == .tiff) || (utType == .bmp) || (utType == .gif)
        let supportsMetadata = isWritable // ImageIO can generally write metadata for common writable types
        let resizeRestricted = false // For Apple-native formats we consider resizing unrestricted
        return FormatCapabilities(
            isReadable: isReadable,
            isWritable: isWritable,
            supportsLossless: supportsLossless,
            supportsQuality: supportsQuality,
            supportsMetadata: supportsMetadata,
            resizeRestricted: resizeRestricted
        )
    }

    // MARK: - URL helpers
    func formatForURL(_ url: URL) -> ImageFormat? {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty else { return nil }
        if let t = UTType(filenameExtension: ext), t.conforms(to: .image), supportsReading(utType: t) {
            return ImageFormat(utType: t)
        }
        return nil
    }

    func isReadableURL(_ url: URL) -> Bool {
        formatForURL(url) != nil
    }

    func format(forIdentifier id: String) -> ImageFormat? {
        guard let t = UTType(id), t.conforms(to: .image) else { return nil }
        return ImageFormat(utType: t)
    }
} 