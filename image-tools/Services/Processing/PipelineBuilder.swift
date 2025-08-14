import Foundation

struct PipelineBuilder {
    func build(sizeUnit: SizeUnitToggle,
               resizePercent: Double,
               resizeWidth: String,
               resizeHeight: String,
               selectedFormat: ImageFormat?,
               compressionPercent: Double,
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
        pipeline.finalFormat = selectedFormat
        pipeline.compressionPercent = compressionPercent

        // Resize
        if sizeUnit == .percent, resizePercent != 1.0 {
            pipeline.add(ResizeOperation(mode: .percent(resizePercent)))
        } else if sizeUnit == .pixels, (Int(resizeWidth) != nil || Int(resizeHeight) != nil) {
            pipeline.add(ResizeOperation(mode: .pixels(width: Int(resizeWidth), height: Int(resizeHeight))))
        }

        // Enforce format-specific size constraints before conversion
        if let fmt = selectedFormat {
            let caps = ImageIOCapabilities.shared
            if caps.sizeRestrictions(forUTType: fmt.utType) != nil {
                pipeline.add(ConstrainSizeOperation(targetFormat: fmt))
            }
        }

        // Compression handled at final export via pipeline.compressionPercent

        // Flip
        if flipH { pipeline.add(FlipOperation(direction: .horizontal)) }
        if flipV { pipeline.add(FlipOperation(direction: .vertical)) }

        // Remove background
        if removeBackground { pipeline.add(RemoveBackgroundOperation()) }

        return pipeline
    }
}


