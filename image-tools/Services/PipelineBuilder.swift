import Foundation

struct PipelineBuilder {
    func build(sizeUnit: SizeUnitToggle,
               resizePercent: Double,
               resizeWidth: String,
               resizeHeight: String,
               selectedFormat: ImageFormat?,
               compressionMode: CompressionModeToggle,
               compressionPercent: Double,
               compressionTargetKB: String,
               flipH: Bool,
               flipV: Bool,
               removeBackground: Bool,
               overwriteOriginals: Bool,
               removeMetadata: Bool,
               exportDirectory: URL?) -> ProcessingPipeline {
        var pipeline = ProcessingPipeline()
        pipeline.overwriteOriginals = overwriteOriginals
        pipeline.removeMetadata = removeMetadata
        pipeline.exportDirectory = exportDirectory

        // Resize
        if sizeUnit == .percent, resizePercent != 1.0 {
            pipeline.add(ResizeOperation(mode: .percent(resizePercent)))
        } else if sizeUnit == .pixels, (Int(resizeWidth) != nil || Int(resizeHeight) != nil) {
            pipeline.add(ResizeOperation(mode: .pixels(width: Int(resizeWidth), height: Int(resizeHeight))))
        }

        // Convert (skip when Original is selected)
        if let fmt = selectedFormat { pipeline.add(ConvertOperation(format: fmt)) }

        // Compress
        switch compressionMode {
        case .percent:
            if compressionPercent < 0.999 {
                pipeline.add(CompressOperation(mode: .percent(compressionPercent), formatHint: selectedFormat))
            }
        case .targetKB:
            if let kb = Int(compressionTargetKB), kb > 0 {
                pipeline.add(CompressOperation(mode: .targetKB(kb), formatHint: selectedFormat))
            }
        }

        // // Rotate - omitted, as in original

        // Flip
        if flipH { pipeline.add(FlipOperation(direction: .horizontal)) }
        if flipV { pipeline.add(FlipOperation(direction: .vertical)) }

        // Remove background
        if removeBackground { pipeline.add(RemoveBackgroundOperation()) }

        return pipeline
    }
}


