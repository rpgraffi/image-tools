import Foundation
import SwiftUI

extension ImageToolsViewModel {
    func buildPipeline() -> ProcessingPipeline {
        let pipeline = PipelineBuilder().build(
            sizeUnit: sizeUnit,
            resizePercent: resizePercent,
            resizeWidth: resizeWidth,
            resizeHeight: resizeHeight,
            selectedFormat: selectedFormat,
            compressionPercent: compressionPercent,
            flipH: flipH,
            flipV: flipV,
            removeBackground: removeBackground,
            overwriteOriginals: overwriteOriginals,
            removeMetadata: removeMetadata,
            exportDirectory: exportDirectory
        )
        if let fmt = selectedFormat { bumpRecentFormats(fmt) }
        return pipeline
    }

    func applyPipeline() {
        let pipeline = buildPipeline()
        let targets = images.filter { $0.isEnabled }

        var updatedImages: [ImageAsset] = images

        for asset in targets {
            do {
                let updated = try pipeline.run(on: asset)
                if let idx = updatedImages.firstIndex(of: asset) { updatedImages[idx] = updated }
            } catch {
                print("Processing failed for \(asset.originalURL.lastPathComponent): \(error)")
            }
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.3)) { images = updatedImages }
    }

    // Async concurrent export
    func recommendedConcurrency() -> Int {
        let info = ProcessInfo.processInfo
        var concurrency = min(16, max(4, info.activeProcessorCount * 2))
        // Adjust for physical memory bands (rough heuristic)
        let gb = Double(info.physicalMemory) / (1024.0 * 1024.0 * 1024.0)
        if gb < 4.0 { concurrency = min(concurrency, 4) }
        else if gb < 8.0 { concurrency = min(concurrency, 8) }
        if info.isLowPowerModeEnabled { concurrency = max(4, min(concurrency, 8)) }
        switch info.thermalState {
        case .fair:
            concurrency = min(concurrency, 8)
        case .serious, .critical:
            concurrency = min(concurrency, 4)
        default:
            break
        }
        return max(2, min(concurrency, 16))
    }

    func applyPipelineAsync() {
        let pipeline = buildPipeline()
        let targets = images.filter { $0.isEnabled }
        guard !targets.isEmpty else { return }

        exportTotal = targets.count
        exportCompleted = 0
        isExporting = true

        Task(priority: .userInitiated) {
            // Snapshot to mutate off-main, then commit on completion
            var updatedImages = await MainActor.run { self.images }
            let maxConcurrent = recommendedConcurrency()
            var index = 0
            while index < targets.count {
                let end = min(index + maxConcurrent, targets.count)
                let slice = Array(targets[index..<end])
                await withTaskGroup(of: (ImageAsset, ImageAsset)?.self) { group in
                    for asset in slice {
                        group.addTask(priority: .utility) {
                            do {
                                let updated = try pipeline.run(on: asset)
                                return (asset, updated)
                            } catch {
                                return nil
                            }
                        }
                    }
                    for await result in group {
                        if let (original, updated) = result {
                            if let idx = updatedImages.firstIndex(of: original) {
                                updatedImages[idx] = updated
                            }
                        }
                        await MainActor.run {
                            self.exportCompleted += 1
                        }
                    }
                }
                index = end
                await Task.yield()
            }

            let imagesToCommit = updatedImages
            await MainActor.run {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.3)) {
                    self.images = imagesToCommit
                }
                self.isExporting = false
                self.exportCompleted = 0
                self.exportTotal = 0
            }
        }
    }

    // Recovery
    func recoverOriginal(_ asset: ImageAsset) {
        guard let backup = asset.backupURL else { return }
        do {
            if FileManager.default.fileExists(atPath: asset.originalURL.path) { try FileManager.default.removeItem(at: asset.originalURL) }
            try FileManager.default.copyItem(at: backup, to: asset.originalURL)
            var updated = asset
            updated.workingURL = asset.originalURL
            updated.isEdited = false
            if let idx = images.firstIndex(of: asset) { images[idx] = updated }
        } catch { print("Recovery failed: \(error)") }
    }
}


