import Foundation
import CoreImage
import UniformTypeIdentifiers

struct ProcessingPipeline {
    var operations: [ImageOperation] = []
    var removeMetadata: Bool = false
    var exportDirectory: URL? = nil
    var finalFormat: ImageFormat? = nil
    var compressionPercent: Double? = nil

    mutating func add(_ op: ImageOperation) {
        operations.append(op)
    }

    func run(on asset: ImageAsset) throws -> ImageAsset {
        let result = asset
        let currentURL = result.originalURL

        // Start security-scoped access if needed
        guard let sourceToken = SandboxAccessToken(url: currentURL) else {
            throw ImageOperationError.permissionDenied
        }
        defer { sourceToken.stop() }

        // Process and encode once according to selected format and compression
        let encoded = try processAndEncode(from: currentURL)
        let plan = destinationPlan(for: result, uti: encoded.uti)

        // Write into destination directory and atomically replace/move into place
        let destParent = plan.directory
        guard let accessToken = SandboxAccessManager.shared.beginAccess(for: destParent) else {
            throw ImageOperationError.permissionDenied
        }
        defer { accessToken.stop() }

        let tempFilename = plan.filenameStem + "_tmp_" + String(UUID().uuidString.prefix(8)) + "." + plan.fileExtension
        let tempInDest = destParent.appendingPathComponent(tempFilename)
        try encoded.data.write(to: tempInDest, options: [.atomic])
        if FileManager.default.fileExists(atPath: plan.url.path) {
            _ = try FileManager.default.replaceItemAt(plan.url, withItemAt: tempInDest, backupItemName: nil, options: [])
        } else {
            try FileManager.default.moveItem(at: tempInDest, to: plan.url)
        }

        var updated = result
        updated.workingURL = plan.url
        updated.isEdited = true
        // Record a successful single-image conversion
        UsageTracker.shared.recordImageConversion()
        return updated
    }

    // Apply operations and return a temporary file URL for the processed image without committing to a destination
    func renderTemporaryURL(on asset: ImageAsset) throws -> URL {
        let currentURL = asset.originalURL
        guard let token = SandboxAccessToken(url: currentURL) else {
            throw ImageOperationError.permissionDenied
        }
        defer { token.stop() }
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
        guard let token = SandboxAccessToken(url: originalURL) else {
            throw ImageOperationError.permissionDenied
        }
        defer { token.stop() }

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

    /// Compute the destination URL without performing any processing, matching the naming behavior of `run(on:)`.
    func plannedDestinationURL(for asset: ImageAsset) -> URL {
        let currentURL = asset.originalURL
        let chosenFormat = finalFormat ?? ImageExporter.inferFormat(from: currentURL)
        let finalUTI = ImageExporter.decideUTTypeForExport(originalURL: currentURL, requestedFormat: chosenFormat)
        let plan = destinationPlan(for: asset, uti: finalUTI)
        return plan.url
    }
} 

private extension ProcessingPipeline {
    struct DestinationPlan {
        let url: URL
        let directory: URL
        let filenameStem: String
        let fileExtension: String
    }

    func destinationPlan(for asset: ImageAsset, uti: UTType) -> DestinationPlan {
        let currentURL = asset.originalURL
        let ext = ImageIOCapabilities.shared.preferredFilenameExtension(for: uti)
        let tempDirPath = FileManager.default.temporaryDirectory.standardizedFileURL.path
        let isTempSource = currentURL.standardizedFileURL.path.hasPrefix(tempDirPath)

        let destinationURL: URL
        if let exportDir = exportDirectory {
            let base = currentURL.deletingPathExtension().lastPathComponent
            destinationURL = exportDir.appendingPathComponent(base + "." + ext)
        } else if isTempSource {
            let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? FileManager.default.homeDirectoryForCurrentUser
            let base = currentURL.deletingPathExtension().lastPathComponent
            destinationURL = downloadsDir.appendingPathComponent(base + "." + ext)
        } else {
            let dir = currentURL.deletingLastPathComponent()
            let base = currentURL.deletingPathExtension().lastPathComponent
            destinationURL = dir.appendingPathComponent(base + "." + ext)
        }

        let directory = destinationURL.deletingLastPathComponent()
        let stem = destinationURL.deletingPathExtension().lastPathComponent
        return DestinationPlan(url: destinationURL, directory: directory, filenameStem: stem, fileExtension: ext)
    }
}
