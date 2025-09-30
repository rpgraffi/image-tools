import Foundation

extension ImageToolsViewModel {
    private func mergeEstimatedBytes(with map: [UUID: Int]) {
        estimatedBytes.merge(map) { _, new in new }
    }

    func triggerEstimationForVisible(_ visibleAssets: [ImageAsset]) {
        // Cancel previous run
        estimationTask?.cancel()
        let sizeUnit = self.sizeUnit
        let resizePercent = self.resizePercent
        let resizeWidth = self.resizeWidth
        let resizeHeight = self.resizeHeight
        let selectedFormat = self.selectedFormat
        let compressionPercent = self.compressionPercent
        let removeMetadata = self.removeMetadata
        let removeBackground = self.removeBackground

        estimationTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }
            let enabled = visibleAssets
            let map = await TrueSizeEstimator.estimate(
                assets: enabled,
                sizeUnit: sizeUnit,
                resizePercent: resizePercent,
                resizeWidth: resizeWidth,
                resizeHeight: resizeHeight,
                selectedFormat: selectedFormat,
                compressionPercent: compressionPercent,
                flipV: flipV,
                removeMetadata: removeMetadata,
                removeBackground: removeBackground
            )
            self.mergeEstimatedBytes(with: map)
        }
    }
}


