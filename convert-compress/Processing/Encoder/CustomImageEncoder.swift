import Foundation
import CoreGraphics
import UniformTypeIdentifiers

protocol CustomImageEncoder {
    func canEncode(utType: UTType) -> Bool
    func encode(cgImage: CGImage, pixelSize: CGSize, utType: UTType, compressionQuality: Double?, stripMetadata: Bool) throws -> Data
}

struct CustomImageEncoderRegistry {
    private static let encoders: [CustomImageEncoder] = [
        WebPEncoder()
    ]

    static func encoder(for utType: UTType) -> CustomImageEncoder? {
        encoders.first { $0.canEncode(utType: utType) }
    }
}


