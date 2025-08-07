import Foundation

struct ProcessingPipeline {
    var operations: [ImageOperation] = []
    var overwriteOriginals: Bool = false

    mutating func add(_ op: ImageOperation) {
        operations.append(op)
    }

    func run(on asset: ImageAsset) throws -> ImageAsset {
        var result = asset
        var currentURL = result.workingURL

        // Start security-scoped access if needed
        var didStartAccessing = false
        if currentURL.startAccessingSecurityScopedResource() {
            didStartAccessing = true
        }
        defer {
            if didStartAccessing { currentURL.stopAccessingSecurityScopedResource() }
        }

        // Backup before first edit if overwriting
        if overwriteOriginals && result.backupURL == nil {
            let backupURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(currentURL.deletingPathExtension().lastPathComponent + "_backup_" + UUID().uuidString.prefix(8))
                .appendingPathExtension(currentURL.pathExtension)
            try? FileManager.default.copyItem(at: result.originalURL, to: backupURL)
            result.backupURL = backupURL
        }

        for op in operations {
            currentURL = try op.apply(to: currentURL)
        }

        // Decide destination
        let destinationURL: URL
        if overwriteOriginals {
            destinationURL = result.originalURL
        } else {
            let dir = result.originalURL.deletingLastPathComponent()
            let base = result.originalURL.deletingPathExtension().lastPathComponent
            let ext = currentURL.pathExtension
            destinationURL = dir.appendingPathComponent(base + "_edited." + ext)
        }

        // Move temp file to destination; request access to destination directory
        let destParent = destinationURL.deletingLastPathComponent()
        var didStartDestAccess = false
        if destParent.startAccessingSecurityScopedResource() {
            didStartDestAccess = true
        }
        defer {
            if didStartDestAccess { destParent.stopAccessingSecurityScopedResource() }
        }

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.moveItem(at: currentURL, to: destinationURL)

        var updated = result
        updated.workingURL = destinationURL
        updated.thumbnail = ThumbnailGenerator.generateThumbnail(for: destinationURL)
        updated.isEdited = true
        return updated
    }
} 