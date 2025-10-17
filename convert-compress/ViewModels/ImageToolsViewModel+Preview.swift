import Foundation

extension ImageToolsViewModel {
    func previewInfo(for asset: ImageAsset) -> PreviewInfo {
        PreviewEstimator().estimate(
            for: asset,
            resizeMode: resizeMode,
            resizeWidth: resizeWidth,
            resizeHeight: resizeHeight,
            compressionPercent: compressionPercent,
            selectedFormat: selectedFormat
        )
    }
}


