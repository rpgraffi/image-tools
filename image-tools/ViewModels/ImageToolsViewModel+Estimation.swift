import Foundation

extension ImageToolsViewModel {
    func triggerEstimationForVisible(_ visibleAssets: [ImageAsset]) {
        // Cancel previous run
        estimationTask?.cancel()
        let sizeUnit = self.sizeUnit
        let resizePercent = self.resizePercent
        let resizeWidth = self.resizeWidth
        let resizeHeight = self.resizeHeight
        let selectedFormat = self.selectedFormat
        let compressionMode = self.compressionMode
        let compressionPercent = self.compressionPercent
        let compressionTargetKB = self.compressionTargetKB
        let removeMetadata = self.removeMetadata

        estimationTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }
            let enabled = visibleAssets.filter { $0.isEnabled }
            let map = await TrueSizeEstimator.estimate(
                assets: enabled,
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
            await MainActor.run {
                self.estimatedBytes.merge(map) { _, new in new }
            }
        }
    }

    func scheduleReestimation() {
        // UI should call triggerEstimationForVisible with current viewport items; leave here as a hook if needed.
        // No-op: orchestrated from Views via onAppear/onChange with visible assets.
    }
}


