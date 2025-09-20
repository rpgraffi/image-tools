import Foundation
import AppKit
import UniformTypeIdentifiers
import SDWebImage
import SDWebImageWebPCoder

struct WebPEncoder: CustomImageEncoder {
    func canEncode(utType: UTType) -> Bool {
        return utType == UTType.webP
    }

    func encode(cgImage: CGImage, pixelSize: CGSize, utType: UTType, compressionQuality: Double?, stripMetadata: Bool) throws -> Data {
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: pixelSize.width, height: pixelSize.height))
        var options: [SDImageCoderOption: Any] = [:]
        if let q = compressionQuality { options[.encodeCompressionQuality] = q }
        options[.encodeWebPMethod] = 0.5
        guard let data = SDImageWebPCoder.shared.encodedData(with: nsImage, format: .webP, options: options) else {
            throw ImageOperationError.exportFailed
        }
        return data
    }
}


