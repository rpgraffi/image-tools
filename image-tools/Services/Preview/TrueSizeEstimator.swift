import Foundation
import CoreImage

struct TrueSizeEstimator {
    struct Result {
        let assetId: UUID
        let bytes: Int
    }

    // Estimate encoded byte sizes for assets concurrently. Skips flips for speed as requested.
    static func estimate(
        assets: [ImageAsset],
        sizeUnit: SizeUnitToggle,
        resizePercent: Double,
        resizeWidth: String,
        resizeHeight: String,
        selectedFormat: ImageFormat?,
        compressionMode: CompressionModeToggle,
        compressionPercent: Double,
        compressionTargetKB: String,
        removeMetadata: Bool
    ) async -> [UUID: Int] {
        guard !assets.isEmpty else { return [:] }

        // Concurrency limit to keep UI responsive
        let maxConcurrent = 4
        var results: [UUID: Int] = [:]
        var index = 0

        while index < assets.count {
            let end = min(index + maxConcurrent, assets.count)
            let slice = Array(assets[index..<end])
            await withTaskGroup(of: (UUID, Int)?.self) { group in
                for asset in slice {
                    group.addTask(priority: .utility) {
                        return estimateOne(
                            asset: asset,
                            sizeUnit: sizeUnit,
                            resizePercent: resizePercent,
                            resizeWidth: resizeWidth,
                            resizeHeight: resizeHeight,
                            selectedFormat: selectedFormat,
                            compressionMode: compressionMode,
                            compressionPercent: compressionPercent,
                            compressionTargetKB: compressionTargetKB,
                            removeMetadata: removeMetadata
                        )
                    }
                }
                for await item in group {
                    if let (id, bytes) = item { results[id] = bytes }
                }
            }
            index = end
            // Yield to keep UI responsive
            await Task.yield()
        }

        return results
    }

    private static func estimateOne(
        asset: ImageAsset,
        sizeUnit: SizeUnitToggle,
        resizePercent: Double,
        resizeWidth: String,
        resizeHeight: String,
        selectedFormat: ImageFormat?,
        compressionMode: CompressionModeToggle,
        compressionPercent: Double,
        compressionTargetKB: String,
        removeMetadata: Bool
    ) -> (UUID, Int)? {
        do {
            // Load and normalize orientation
            var ci = try loadCIImageApplyingOrientation(from: asset.workingURL)

            // Resize by UI settings
            switch sizeUnit {
            case .percent:
                if abs(resizePercent - 1.0) > 0.0001 {
                    ci = try ResizeOperation(mode: .percent(resizePercent)).transformed(ci)
                }
            case .pixels:
                if (Int(resizeWidth) != nil) || (Int(resizeHeight) != nil) {
                    ci = try ResizeOperation(mode: .pixels(width: Int(resizeWidth), height: Int(resizeHeight))).transformed(ci)
                }
            }

            // Enforce format constraints if any
            if let fmt = selectedFormat {
                ci = try ConstrainSizeOperation(targetFormat: fmt).transformed(ci)
            }

            // Build encoder parameters
            let targetFormat = selectedFormat ?? ImageExporter.inferFormat(from: asset.workingURL)

            // Compression handling
            let bytes: Int
            switch compressionMode {
            case .percent:
                let q = max(min(compressionPercent, 1.0), 0.01)
                let encoded = try ImageExporter.encodeToData(ciImage: ci, originalURL: asset.workingURL, format: targetFormat, compressionQuality: q, stripMetadata: removeMetadata)
                bytes = encoded.data.count
            case .targetKB:
                if let kb = Int(compressionTargetKB), kb > 0 {
                    let targetBytes = max(kb, 1) * 1024
                    var low: Double = 0.05
                    var high: Double = 0.95
                    var quality: Double = 0.9
                    var bestBytes = Int.max
                    for _ in 0..<8 {
                        let encoded = try ImageExporter.encodeToData(ciImage: ci, originalURL: asset.workingURL, format: targetFormat, compressionQuality: quality, stripMetadata: removeMetadata)
                        let size = encoded.data.count
                        if size > targetBytes {
                            high = quality
                            quality = (low + quality) / 2
                        } else {
                            bestBytes = size
                            low = quality
                            quality = (quality + high) / 2
                        }
                    }
                    bytes = (bestBytes == Int.max) ? targetBytes : bestBytes
                } else {
                    // Fallback to percent path if no KB provided
                    let encoded = try ImageExporter.encodeToData(ciImage: ci, originalURL: asset.workingURL, format: targetFormat, compressionQuality: 0.9, stripMetadata: removeMetadata)
                    bytes = encoded.data.count
                }
            }
            return (asset.id, bytes)
        } catch {
            return nil
        }
    }
}


