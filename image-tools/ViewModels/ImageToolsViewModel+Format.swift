import Foundation

extension ImageToolsViewModel {
    func updateRestrictions() {
        let caps = ImageIOCapabilities.shared
        if let fmt = selectedFormat, let set = caps.sizeRestrictions(forUTType: fmt.utType) {
            let sizes = set.sorted()
            allowedSquareSizes = sizes
            let sizesText = sizes.map { String($0) }.joined(separator: ", ")
            if let name = selectedFormat?.displayName {
                restrictionHint = "\(name) requires square sizes: \(sizesText)."
            } else {
                restrictionHint = "Requires square sizes: \(sizesText)."
            }
        } else {
            allowedSquareSizes = nil
            restrictionHint = nil
        }
    }

    func onSelectedFormatChanged() {
        updateRestrictions()
        guard allowedSquareSizes != nil else { return }
        // Choose a reference size from first enabled asset
        let targets: [ImageAsset] = images
        guard let first = (targets.first) ?? targets.first else { return }
        let srcSize = ImageMetadata.pixelSize(for: first.originalURL) ?? first.originalPixelSize ?? .zero
        let caps = ImageIOCapabilities.shared
        if let fmt = selectedFormat, !caps.isValidPixelSize(srcSize, for: fmt.utType) {
            // Force pixel mode and prefill suggestion
            sizeUnit = .pixels
            if let side = caps.suggestedSquareSide(for: fmt.utType, source: srcSize) {
                resizeWidth = String(side)
                resizeHeight = String(side)
            }
        }
    }
}


