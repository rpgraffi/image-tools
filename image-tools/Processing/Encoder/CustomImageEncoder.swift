import Foundation
import CoreGraphics
import UniformTypeIdentifiers

protocol CustomImageEncoder {
    func canEncode(utType: UTType) -> Bool
    func encode(cgImage: CGImage, pixelSize: CGSize, utType: UTType, compressionQuality: Double?, stripMetadata: Bool) throws -> Data
}

final class CustomImageEncoderRegistry {
    static let shared = CustomImageEncoderRegistry()
    private var encoders: [CustomImageEncoder] = []

    private init() {
        // Register built-in custom encoders here
        encoders.append(WebPEncoder())
    }

    func encoder(for utType: UTType) -> CustomImageEncoder? {
        return encoders.first { $0.canEncode(utType: utType) }
    }
}


