import Foundation
import UniformTypeIdentifiers
import ImageIO

final class ImageIOCapabilities {
    static let shared = ImageIOCapabilities()

    private let writableTypes: Set<String>

    private init() {
        if let ids = CGImageDestinationCopyTypeIdentifiers() as? [String] {
            self.writableTypes = Set(ids)
        } else {
            self.writableTypes = []
        }
    }

    func supportsWriting(utType: UTType) -> Bool {
        writableTypes.contains(utType.identifier)
    }

    func preferredFilenameExtension(for utType: UTType) -> String {
        if utType == .jpeg { return "jpg" }
        return utType.preferredFilenameExtension ?? "img"
    }
} 