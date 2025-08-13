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
            let input: ResizeInput = {
                switch sizeUnit {
                case .percent:
                    return .percent(resizePercent)
                case .pixels:
                    return .pixels(width: Int(resizeWidth), height: Int(resizeHeight))
                }
            }()
            // Preview should not upscale
            var size = ResizeMath.targetSize(for: base, input: input, noUpscale: true)
            // If format enforces square sizes in preview, clamp to min side
            if let selected = selectedFormat, ImageIOCapabilities.shared.sizeRestrictions(forUTType: selected.utType) != nil {
                let side = min(size.width, size.height)
                size = CGSize(width: side, height: side)
            }
            return size
        }()
        // Report no bytes here; UI will show "--- KB" until background estimator fills it.
        return PreviewInfo(targetPixelSize: targetSize, estimatedOutputBytes: nil)
    }
}

