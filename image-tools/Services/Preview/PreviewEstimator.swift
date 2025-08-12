import Foundation

struct PreviewInfo {
    let targetPixelSize: CGSize?
    let estimatedOutputBytes: Int?
}

struct PreviewEstimator {
    // Keep only target pixel size calculation for layout; do not estimate bytes here.
    func estimate(for asset: ImageAsset,
                  sizeUnit: SizeUnitToggle,
                  resizePercent: Double,
                  resizeWidth: String,
                  resizeHeight: String,
                  compressionMode: CompressionModeToggle,
                  compressionPercent: Double,
                  compressionTargetKB: String,
                  selectedFormat: ImageFormat?) -> PreviewInfo {
        let baseSize: CGSize? = asset.originalPixelSize
        let targetSize: CGSize? = {
            guard let base = baseSize else { return CGSize(width: 0, height: 0) }
            switch sizeUnit {
            case .percent:
                let scale = resizePercent
                var w = base.width * scale
                var h = base.height * scale
                if let selected = selectedFormat, ImageIOCapabilities.shared.sizeRestrictions(forUTType: selected.utType) != nil {
                    let side = min(w, h)
                    w = side; h = side
                }
                return CGSize(width: w, height: h)
            case .pixels:
                let w = Int(resizeWidth)
                let h = Int(resizeHeight)
                let width = CGFloat(w ?? Int(base.width))
                let height = CGFloat(h ?? Int(base.height))
                return CGSize(width: max(1, width), height: max(1, height))
            }
        }()
        // Report no bytes here; UI will show "--- KB" until background estimator fills it.
        return PreviewInfo(targetPixelSize: targetSize, estimatedOutputBytes: nil)
    }
}

