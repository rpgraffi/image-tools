import Foundation
import CoreImage

struct ProcessingPipeline {
    var operations: [ImageOperation] = []
    var overwriteOriginals: Bool = false
    var removeMetadata: Bool = false
    var exportDirectory: URL? = nil
    var finalFormat: ImageFormat? = nil
    var compressionPercent: Double? = nil

    mutating func add(_ op: ImageOperation) {
        operations.append(op)
    }

    func run(on asset: ImageAsset) throws -> ImageAsset {
        var result = asset
        var currentURL = result.originalURL

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

        // Load once and apply all operations in-memory
        guard var ci = try? loadCIImageApplyingOrientation(from: currentURL) else {
            throw ImageOperationError.loadFailed
        }
        for op in operations {
            ci = try op.transformed(ci)
        }

        // One final export with selected format and compression
        let chosenFormat = finalFormat ?? ImageExporter.inferFormat(from: currentURL)
        let q = compressionPercent.map { max(min($0, 1.0), 0.01) }
        currentURL = try ImageExporter.export(ciImage: ci, originalURL: currentURL, format: chosenFormat, compressionQuality: q, stripMetadata: removeMetadata)

        // Decide destination
        let destinationURL: URL
        let tempDirPath = FileManager.default.temporaryDirectory.standardizedFileURL.path
        let isTempSource = result.originalURL.standardizedFileURL.path.hasPrefix(tempDirPath)

        if overwriteOriginals {
            destinationURL = result.originalURL
        } else if let exportDir = exportDirectory {
            let base = result.originalURL.deletingPathExtension().lastPathComponent
            let ext = currentURL.pathExtension
            destinationURL = exportDir.appendingPathComponent(base + "_edited." + ext)
        } else if isTempSource {
            // Pasted images saved into temp should end up in Downloads upon apply
            let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? FileManager.default.homeDirectoryForCurrentUser
            let base = result.originalURL.deletingPathExtension().lastPathComponent
            let ext = currentURL.pathExtension
            destinationURL = downloadsDir.appendingPathComponent(base + "_edited." + ext)
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
        updated.isEdited = true
        return updated
    }

    // Apply operations and return a temporary file URL for the processed image without committing to a destination
    func renderTemporaryURL(on asset: ImageAsset) throws -> URL {
        var currentURL = asset.originalURL

        var didStartAccessing = false
        if currentURL.startAccessingSecurityScopedResource() {
            didStartAccessing = true
        }
        defer {
            if didStartAccessing { currentURL.stopAccessingSecurityScopedResource() }
        }

        // Render in-memory instead of writing per-op
        guard var ci = try? loadCIImageApplyingOrientation(from: currentURL) else {
            throw ImageOperationError.loadFailed
        }
        for op in operations {
            ci = try op.transformed(ci)
        }
        let chosenFormat = finalFormat ?? ImageExporter.inferFormat(from: currentURL)
        let q = compressionPercent.map { max(min($0, 1.0), 0.01) }
        currentURL = try ImageExporter.export(ciImage: ci, originalURL: currentURL, format: chosenFormat, compressionQuality: q, stripMetadata: removeMetadata)

        return currentURL
    }
} 