import Foundation

struct PipelineBuilder {
    func build(resizeMode: ResizeMode,
               resizeWidth: String,
               resizeHeight: String,
               selectedFormat: ImageFormat?,
               compressionPercent: Double,
               flipV: Bool,
               removeBackground: Bool,
               removeMetadata: Bool,
               exportDirectory: URL?) -> ProcessingPipeline {
        var pipeline = ProcessingPipeline()
        pipeline.removeMetadata = removeMetadata
        pipeline.exportDirectory = exportDirectory
        pipeline.finalFormat = selectedFormat
        pipeline.compressionPercent = compressionPercent

        let widthInt = Int(resizeWidth)
        let heightInt = Int(resizeHeight)
        
        // Handle resize or crop based on mode
        if resizeMode == .crop, let w = widthInt, let h = heightInt {
            // Both dimensions filled in crop mode: CropOperation handles resize + crop internally
            pipeline.add(CropOperation(targetWidth: w, targetHeight: h))
        } else if widthInt != nil || heightInt != nil {
            // One or both dimensions filled in resize mode, or only one dimension in crop mode: resize maintaining aspect ratio
            pipeline.add(ResizeOperation(mode: .pixels(width: widthInt, height: heightInt)))
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
        if flipV { pipeline.add(FlipVerticalOperation()) }

        // Remove background
        if removeBackground { pipeline.add(RemoveBackgroundOperation()) }

        return pipeline
    }
}


