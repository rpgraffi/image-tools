import Foundation
import SwiftUI
import AppKit

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
        // Show paywall first when user is not unlocked, unless explicitly bypassed for this request.
        if !PurchaseManager.shared.isProUnlocked && !shouldBypassPaywallOnce {
            isPaywallPresented = true
            return
        }
        shouldBypassPaywallOnce = false
        let pipeline = buildPipeline()
        let targets = images.filter { $0.isEnabled }
        guard !targets.isEmpty else { return }

        // Preflight replace confirmation (single dialog for all files)
        if !preflightReplaceIfNecessary(pipeline: pipeline, targets: targets) {
            return
        }

        exportTotal = targets.count
        exportCompleted = 0
        isExporting = true

        Task(priority: .userInitiated) {
            let hint = recommendedConcurrency()
            // Snapshot to mutate off-main, then commit on completion
            var updatedImages = await MainActor.run { self.images }

            await withTaskGroup(of: (ImageAsset, ImageAsset)?.self) { group in
                var iterator = targets.makeIterator()
                let boost = max(1, Int(Double(hint) * 1.5))
                let limit = min(boost, targets.count)

                func addNextTask(from iterator: inout IndexingIterator<[ImageAsset]>, to group: inout TaskGroup<(ImageAsset, ImageAsset)?>) {
                    guard let asset = iterator.next() else { return }
                    group.addTask(priority: .utility) {
                        do {
                            let updated = try pipeline.run(on: asset)
                            return (asset, updated)
                        } catch {
                            return nil
                        }
                    }
                }

                for _ in 0..<limit {
                    addNextTask(from: &iterator, to: &group)
                }

                while let result = await group.next() {
                    if let (original, updated) = result,
                       let idx = updatedImages.firstIndex(of: original) {
                        updatedImages[idx] = updated
                    }

                    await MainActor.run {
                        self.exportCompleted += 1
                    }

                    addNextTask(from: &iterator, to: &group)
                    await Task.yield()
                }
            }

            let imagesToCommit = updatedImages
            await MainActor.run {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.3)) {
                    self.images = imagesToCommit
                }
                self.isExporting = false
                self.exportCompleted = 0
                self.exportTotal = 0
                // Record pipeline application once per batch
                UsageTracker.shared.recordPipelineApplied()

                // Reveal exported files in Finder, selecting them when possible
                let urlsToReveal = imagesToCommit.compactMap { $0.isEdited ? $0.workingURL : nil }
                if !urlsToReveal.isEmpty {
                    NSWorkspace.shared.activateFileViewerSelecting(urlsToReveal)
                }
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

extension ImageToolsViewModel {
    /// Returns true if export should proceed, false if user cancelled.
    private func preflightReplaceIfNecessary(pipeline: ProcessingPipeline, targets: [ImageAsset]) -> Bool {
        guard !targets.isEmpty else { return true }
        let planned: [URL] = targets.map { pipeline.plannedDestinationURL(for: $0) }
        // Only unique destinations matter for conflict check
        let uniquePlanned = Array(Set(planned))
        let fm = FileManager.default
        let conflicts = uniquePlanned.filter { fm.fileExists(atPath: $0.path) }
        guard !conflicts.isEmpty else { return true }

        // Prefer showing the parent folder if all in same directory
        let parentDirs = Set(conflicts.map { $0.deletingLastPathComponent().path })
        let folderHintPath = parentDirs.count == 1 ? parentDirs.first! : nil
        let message = String(localized: "Replace existing files?")
        let count = conflicts.count
        var info = ""
        if let folderPath = folderHintPath {
            let folderName = FileManager.default.displayName(atPath: folderPath)
            if count == 1 {
                info = String(format: String(localized: "1 file already exists in \"%@\". Replacing will overwrite it."), folderName)
            } else {
                info = String(format: String(localized: "%d files already exist in \"%@\". Replacing will overwrite them."), count, folderName)
            }
        } else {
            if count == 1 {
                info = String(localized: "1 file with the same name already exists. Replacing will overwrite it.")
            } else {
                info = String(format: String(localized: "%d files with the same name already exist. Replacing will overwrite them."), count)
            }
        }

        func presentAlert() -> Bool {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = message
            alert.informativeText = info
            alert.addButton(withTitle: String(localized: "Replace"))
            alert.addButton(withTitle: String(localized: "Cancel"))
            if let icon = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil) {
                alert.icon = icon
            }
            let resp = alert.runModal()
            return resp == .alertFirstButtonReturn
        }

        return presentAlert()
    }
}


