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
        compressionPercent: Double,
        removeMetadata: Bool,
        removeBackground: Bool
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
                            compressionPercent: compressionPercent,
                            removeMetadata: removeMetadata,
                            removeBackground: removeBackground
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
        compressionPercent: Double,
        removeMetadata: Bool,
        removeBackground: Bool
    ) -> (UUID, Int)? {
        do {
            // Load and normalize orientation from original, not from a previous working file
            var ci = try loadCIImageApplyingOrientation(from: asset.originalURL)

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

            // Background removal. If target format does not support alpha, composite on white.
            if removeBackground {
                if let masked = try? removeBackgroundCIImage(ci) {
                    if let fmt = selectedFormat {
                        let caps = ImageIOCapabilities.shared.capabilities(for: fmt)
                        if caps.supportsAlpha {
                            ci = masked
                        } else {
                            let extent = masked.extent
                            let white = CIImage(color: CIColor(red: 1, green: 1, blue: 1, alpha: 1)).cropped(to: extent)
                            let comp = CIFilter.sourceOverCompositing()
                            comp.inputImage = masked
                            comp.backgroundImage = white
                            if let flattened = comp.outputImage { ci = flattened }
                        }
                    } else {
                        ci = masked
                    }
                }
            }

            // Build encoder parameters
        let targetFormat = selectedFormat ?? ImageExporter.inferFormat(from: asset.originalURL)
            let q = max(min(compressionPercent, 1.0), 0.01)
            let encoded = try ImageExporter.encodeToData(ciImage: ci, originalURL: asset.originalURL, format: targetFormat, compressionQuality: q, stripMetadata: removeMetadata)
            let bytes = encoded.data.count
            return (asset.id, bytes)
        } catch {
            return nil
        }
    }
}


