import Foundation

struct PreviewInfo {
    let targetPixelSize: CGSize?
    let estimatedOutputBytes: Int?
}

struct PreviewEstimator {
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
                // If a restricted format is selected and expects square, reflect square in preview
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

        let estimatedBytes: Int? = {
            guard let origBytes = asset.originalFileSizeBytes,
                  let base = baseSize,
                  let target = targetSize,
                  base.width > 0, base.height > 0 else { return asset.originalFileSizeBytes }
            let areaRatio = (target.width * target.height) / (base.width * base.height)
            var bytes = Int(CGFloat(origBytes) * areaRatio)
            switch compressionMode {
            case .percent:
                bytes = Int(CGFloat(bytes) * CGFloat(compressionPercent))
            case .targetKB:
                if let kb = Int(compressionTargetKB), kb > 0 {
                    bytes = kb * 1024
                }
            }
            return max(1, bytes)
        }()

        return PreviewInfo(targetPixelSize: targetSize, estimatedOutputBytes: estimatedBytes)
    }
}


