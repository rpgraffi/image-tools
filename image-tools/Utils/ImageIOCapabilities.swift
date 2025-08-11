import Foundation
import UniformTypeIdentifiers
import ImageIO
import CoreGraphics

final class ImageIOCapabilities {
    static let shared = ImageIOCapabilities()

    private let readableTypes: Set<String>
    private let writableTypes: Set<String>

    private init() {
        if let readIds = CGImageSourceCopyTypeIdentifiers() as? [String] {
            self.readableTypes = Set(readIds)
        } else {
            self.readableTypes = []
        }
        if let writeIds = CGImageDestinationCopyTypeIdentifiers() as? [String] {
            self.writableTypes = Set(writeIds)
        } else {
            self.writableTypes = []
        }
    }

    func supportsWriting(utType: UTType) -> Bool {
        writableTypes.contains(utType.identifier)
    }

    func supportsReading(utType: UTType) -> Bool {
        readableTypes.contains(utType.identifier)
    }

    func preferredFilenameExtension(for utType: UTType) -> String {
        if utType == .jpeg { return "jpg" }
        return utType.preferredFilenameExtension ?? "img"
    }

    // MARK: - Dynamic format lists
    func readableFormats() -> [ImageFormat] {
        allImageFormats().filter { supportsReading(utType: $0.utType) }
    }

    func writableFormats() -> [ImageFormat] {
        allImageFormats().filter { supportsWriting(utType: $0.utType) }
    }

    func allImageFormats() -> [ImageFormat] {
        let union = readableTypes.union(writableTypes)
        var results: [ImageFormat] = []
        for id in union {
            if let t = UTType(id), t.conforms(to: .image) {
                results.append(ImageFormat(utType: t))
            }
        }
        // Ensure some common types appear first in a stable, human-friendly order
        let priority: [String: Int] = [
            UTType.jpeg.identifier: 0,
            UTType.png.identifier: 1,
            UTType.heic.identifier: 2,
            UTType.tiff.identifier: 3,
            UTType.bmp.identifier: 4,
            UTType.gif.identifier: 5
        ]
        return results.sorted { a, b in
            let ai = priority[a.utType.identifier] ?? Int.max
            let bi = priority[b.utType.identifier] ?? Int.max
            if ai != bi { return ai < bi }
            return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
        }
    }

    // MARK: - Capabilities
    func capabilities(for format: ImageFormat) -> FormatCapabilities {
        capabilities(forUTType: format.utType)
    }

    func capabilities(forUTType utType: UTType) -> FormatCapabilities {
        let isReadable = supportsReading(utType: utType)
        let isWritable = supportsWriting(utType: utType)
        let supportsQuality = (utType == .jpeg) || (utType == UTType.heic)
        let supportsLossless = (utType == .png) || (utType == .tiff) || (utType == .bmp) || (utType == .gif)
        let supportsMetadata = supportsPrivacySensitiveMetadata(utType: utType)
        let resizeRestricted = sizeRestrictions(forUTType: utType) != nil
        return FormatCapabilities(
            isReadable: isReadable,
            isWritable: isWritable,
            supportsLossless: supportsLossless,
            supportsQuality: supportsQuality,
            supportsMetadata: supportsMetadata,
            resizeRestricted: resizeRestricted
        )
    }

    // MARK: - Privacy-sensitive metadata detection
    
    /// Determines if a format supports privacy-sensitive metadata like EXIF data
    /// This is used to show/hide the metadata removal control appropriately
    private func supportsPrivacySensitiveMetadata(utType: UTType) -> Bool {
        // Only check writable formats since we can't remove metadata from formats we can't write
        guard supportsWriting(utType: utType) else { return false }
        
        // Common formats that support EXIF and other privacy-sensitive metadata
        let privacyMetadataFormats: Set<String> = [
            UTType.jpeg.identifier,     // JPEG - full EXIF support
            UTType.tiff.identifier,     // TIFF - full EXIF support  
            UTType.heic.identifier,     // HEIC - full EXIF support
            UTType.heif.identifier,     // HEIF - full EXIF support
        ]
        
        // Check if it's a known privacy-sensitive format
        if privacyMetadataFormats.contains(utType.identifier) {
            return true
        }
        
        // For other formats, check if they conform to formats that typically have EXIF
        // Most camera/photo formats support EXIF
        if let cameraRawType = UTType("public.camera-raw-image"), utType.conforms(to: cameraRawType) {
            return true
        }
        if let adobeRawType = UTType("com.adobe.raw-image"), utType.conforms(to: adobeRawType) {
            return true
        }
        
        // Additional check for formats that might support EXIF but aren't in our main list
        // This covers various RAW formats and other photo formats
        let identifier = utType.identifier.lowercased()
        let photoFormatHints = ["raw", "dng", "cr2", "nef", "orf", "arw", "rw2"]
        if photoFormatHints.contains(where: { identifier.contains($0) }) {
            return true
        }
        
        return false
    }

    // MARK: - URL helpers
    func formatForURL(_ url: URL) -> ImageFormat? {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty else { return nil }
        if let t = UTType(filenameExtension: ext), t.conforms(to: .image), supportsReading(utType: t) {
            return ImageFormat(utType: t)
        }
        return nil
    }

    func isReadableURL(_ url: URL) -> Bool {
        formatForURL(url) != nil
    }

    func format(forIdentifier id: String) -> ImageFormat? {
        guard let t = UTType(id), t.conforms(to: .image) else { return nil }
        return ImageFormat(utType: t)
    }

    // MARK: - Size restrictions for formats

    /// Returns the allowed square sizes for the given UTType, if any.
    /// Known cases: ICNS (fixed square set), ICO (fixed square set), PVR/PowerVR (fixed square set)
    func sizeRestrictions(forUTType utType: UTType) -> Set<Int>? {
        // ICNS
        if utType == UTType.icns {
            // Common ICNS pixel variants (backed by Apple's icon sizes)
            return Set([16, 32, 64, 128, 256, 512])
        }
        // ICO – identifier varies; resolve via extension when possible
        if utType.identifier.lowercased().contains("ico") || utType.preferredFilenameExtension == "ico" {
            return Set([16, 32, 48, 128, 256])
        }
        // PVR/PowerVR – treat as fixed square sizes for simplicity
        let id = utType.identifier.lowercased()
        if id.contains("pvr") || id.contains("powervr") {
            return Set([16, 32, 64, 128, 256, 512, 1024, 2048, 4096])
        }
        return nil
    }

    /// Validate a CGSize against format restrictions
    func isValidPixelSize(_ size: CGSize, for utType: UTType) -> Bool {
        guard let allowed = sizeRestrictions(forUTType: utType) else { return true }
        let w = Int(size.width.rounded())
        let h = Int(size.height.rounded())
        return w == h && allowed.contains(w)
    }

    /// Suggest a square side length that satisfies restrictions, closest to the given source size
    func suggestedSquareSide(for utType: UTType, source: CGSize) -> Int? {
        let base = Int(min(source.width, source.height).rounded())
        guard let allowed = sizeRestrictions(forUTType: utType) else { return base }
        // pick nearest allowed side; prefer upscaling to next allowed if equidistant
        let sorted = allowed.sorted()
        var best: Int = sorted.first ?? base
        var bestDist = Int.max
        for s in sorted {
            let d = abs(s - base)
            if d < bestDist || (d == bestDist && s >= base) {
                best = s
                bestDist = d
            }
        }
        return best
    }
} 