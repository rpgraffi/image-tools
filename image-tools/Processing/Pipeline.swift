import Foundation
import CoreImage
import UniformTypeIdentifiers

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

        // Process and encode once according to selected format and compression
        let encoded = try processAndEncode(from: currentURL)
        let ext = ImageIOCapabilities.shared.preferredFilenameExtension(for: encoded.uti)

        // Decide destination
        let destinationURL: URL
        let tempDirPath = FileManager.default.temporaryDirectory.standardizedFileURL.path
        let isTempSource = result.originalURL.standardizedFileURL.path.hasPrefix(tempDirPath)

        if overwriteOriginals {
            destinationURL = result.originalURL
        } else if let exportDir = exportDirectory {
            let base = result.originalURL.deletingPathExtension().lastPathComponent
            destinationURL = exportDir.appendingPathComponent(base + "_edited." + ext)
        } else if isTempSource {
            // Pasted images saved into temp should end up in Downloads upon apply
            let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? FileManager.default.homeDirectoryForCurrentUser
            let base = result.originalURL.deletingPathExtension().lastPathComponent
            destinationURL = downloadsDir.appendingPathComponent(base + "_edited." + ext)
        } else {
            let dir = result.originalURL.deletingLastPathComponent()
            let base = result.originalURL.deletingPathExtension().lastPathComponent
            destinationURL = dir.appendingPathComponent(base + "_edited." + ext)
        }

        // Write into destination directory and atomically replace/move into place
        let destParent = destinationURL.deletingLastPathComponent()
        var didStartDestAccess = false
        if destParent.startAccessingSecurityScopedResource() {
            didStartDestAccess = true
        }
        defer {
            if didStartDestAccess { destParent.stopAccessingSecurityScopedResource() }
        }

        let tempFilename = destinationURL.deletingPathExtension().lastPathComponent + "_tmp_" + String(UUID().uuidString.prefix(8)) + "." + ext
        let tempInDest = destParent.appendingPathComponent(tempFilename)
        try encoded.data.write(to: tempInDest, options: [.atomic])
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            _ = try FileManager.default.replaceItemAt(destinationURL, withItemAt: tempInDest, backupItemName: nil, options: [])
        } else {
            try FileManager.default.moveItem(at: tempInDest, to: destinationURL)
        }

        var updated = result
        updated.workingURL = destinationURL
        updated.isEdited = true
        // Record a successful single-image conversion
        UsageTracker.shared.recordImageConversion()
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
        // Process and encode, then write to a temporary file
        let encoded = try processAndEncode(from: currentURL)
        let tempDir = FileManager.default.temporaryDirectory
        let ext = ImageIOCapabilities.shared.preferredFilenameExtension(for: encoded.uti)
        let base = currentURL.deletingPathExtension().lastPathComponent
        let tempFilename = base + "_tmp_" + String(UUID().uuidString.prefix(8)) + "." + ext
        let outputURL = tempDir.appendingPathComponent(tempFilename)
        try encoded.data.write(to: outputURL, options: [.atomic])
        return outputURL
    }

    // Apply operations and return encoded data with the chosen UTType for clipboard or sharing
    func renderEncodedData(on asset: ImageAsset) throws -> (data: Data, uti: UTType) {
        return try processAndEncode(from: asset.originalURL)
    }

    // MARK: - DRY helper
    private func processAndEncode(from originalURL: URL) throws -> (data: Data, uti: UTType) {
        var didStartAccessing = false
        if originalURL.startAccessingSecurityScopedResource() {
            didStartAccessing = true
        }
        defer {
            if didStartAccessing { originalURL.stopAccessingSecurityScopedResource() }
        }

        guard var ci = try? loadCIImageApplyingOrientation(from: originalURL) else {
            throw ImageOperationError.loadFailed
        }
        for op in operations {
            ci = try op.transformed(ci)
        }
        let chosenFormat = finalFormat ?? ImageExporter.inferFormat(from: originalURL)
        let q = compressionPercent.map { max(min($0, 1.0), 0.01) }
        let encoded = try ImageExporter.encodeToData(ciImage: ci,
                                                     originalURL: originalURL,
                                                     format: chosenFormat,
                                                     compressionQuality: q,
                                                     stripMetadata: removeMetadata)
        return encoded
    }
} 