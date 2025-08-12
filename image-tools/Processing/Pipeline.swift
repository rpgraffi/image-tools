import Foundation
import CoreImage

struct ProcessingPipeline {
    var operations: [ImageOperation] = []
    var overwriteOriginals: Bool = false
    var removeMetadata: Bool = false
    var exportDirectory: URL? = nil

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

        // Apply metadata stripping if requested (re-encode without metadata, preserving format)
        if removeMetadata {
            if let ci = CIImage(contentsOf: currentURL) {
                currentURL = try ImageExporter.export(ciImage: ci, originalURL: currentURL, format: ImageExporter.inferFormat(from: currentURL), compressionQuality: nil, stripMetadata: true)
            }
        }

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
        var currentURL = asset.workingURL

        var didStartAccessing = false
        if currentURL.startAccessingSecurityScopedResource() {
            didStartAccessing = true
        }
        defer {
            if didStartAccessing { currentURL.stopAccessingSecurityScopedResource() }
        }

        for op in operations {
            currentURL = try op.apply(to: currentURL)
        }

        return currentURL
    }
} 