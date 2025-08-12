import Foundation

extension ImageToolsViewModel {
    func previewInfo(for asset: ImageAsset) -> PreviewInfo {
        PreviewEstimator().estimate(
            for: asset,
            sizeUnit: sizeUnit,
            resizePercent: resizePercent,
            resizeWidth: resizeWidth,
            resizeHeight: resizeHeight,
            compressionMode: compressionMode,
            compressionPercent: compressionPercent,
            compressionTargetKB: compressionTargetKB,
            selectedFormat: selectedFormat
        )
    }
}


