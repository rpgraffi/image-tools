import Foundation
import AppKit
import SwiftUI

final class ImageToolsViewModel: ObservableObject {
    @Published var newImages: [ImageAsset] = []
    @Published var editedImages: [ImageAsset] = []

    @Published var overwriteOriginals: Bool = false

    // UI toggles/state
    @Published var sizeUnit: SizeUnitToggle = .percent
    @Published var resizePercent: Double = 1.0
    @Published var resizeWidth: String = ""
    @Published var resizeHeight: String = ""

    @Published var selectedFormat: ImageFormat? = nil { didSet { persistSelectedFormat() } }

    @Published var compressionMode: CompressionModeToggle = .percent
    @Published var compressionPercent: Double = 0.8
    @Published var compressionTargetKB: String = ""

    @Published var rotation: ImageRotation = .r0
    @Published var flipH: Bool = false
    @Published var flipV: Bool = false
    @Published var removeBackground: Bool = false

    // Recently used formats for prioritization
    @Published var recentFormats: [ImageFormat] = [] { didSet { persistRecentFormats() } }

    // MARK: - Init / Persistence
    init() {
        loadPersistedState()
    }

    private let defaults = UserDefaults.standard
    private let recentKey = "image_tools.recent_formats.v1"
    private let selectedKey = "image_tools.selected_format.v1"

    private func loadPersistedState() {
        if let raw = defaults.array(forKey: recentKey) as? [String] {
            let mapped = raw.compactMap { ImageFormat(rawValue: $0) }
            if !mapped.isEmpty { recentFormats = Array(mapped.prefix(3)) }
        }
        if let selRaw = defaults.string(forKey: selectedKey), let fmt = ImageFormat(rawValue: selRaw) {
            let caps = ImageIOCapabilities.shared
            if caps.supportsWriting(utType: fmt.utType) { selectedFormat = fmt }
        }
    }

    private func persistRecentFormats() { defaults.set(recentFormats.map { $0.rawValue }, forKey: recentKey) }
    private func persistSelectedFormat() { defaults.set(selectedFormat?.rawValue, forKey: selectedKey) }

    // MARK: - Preview calculations (reusable service-like helpers)
    struct PreviewInfo {
        let targetPixelSize: CGSize?
        let estimatedOutputBytes: Int?
    }

    func previewInfo(for asset: ImageAsset) -> PreviewInfo {
        // Pixel size
        let baseSize: CGSize? = asset.originalPixelSize
        let targetSize: CGSize? = {
            guard let base = baseSize else { return nil }
            switch sizeUnit {
            case .percent:
                let scale = resizePercent
                return CGSize(width: base.width * scale, height: base.height * scale)
            case .pixels:
                let w = Int(resizeWidth)
                let h = Int(resizeHeight)
                let width = CGFloat(w ?? Int(base.width))
                let height = CGFloat(h ?? Int(base.height))
                return CGSize(width: max(1, width), height: max(1, height))
            }
        }()

        // Estimate output size in bytes (rough heuristic)
        // Use original bytes and scale by pixel area ratio, then apply compression factor if any
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

    // MARK: - Ingestion
    func addURLs(_ urls: [URL]) {
        let imageURLs = urls.filter { isSupportedImage($0) }
        let assets = imageURLs.map { ImageAsset(url: $0) }
        newImages.append(contentsOf: assets)
    }

    private func isSupportedImage(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["jpg","jpeg","png","heic","tiff","tif","bmp","gif","webp"].contains(ext)
    }

    // MARK: - Enable/Disable & Move between sections
    func toggleEnable(_ asset: ImageAsset) {
        if let idx = newImages.firstIndex(of: asset) {
            newImages[idx].isEnabled.toggle()
        } else if let idx = editedImages.firstIndex(of: asset) {
            editedImages[idx].isEnabled.toggle()
        }
    }

    func moveToNew(_ asset: ImageAsset) {
        if let idx = editedImages.firstIndex(of: asset) {
            var item = editedImages.remove(at: idx)
            item.isEnabled = true
            newImages.append(item)
        }
    }

    // MARK: - Prefill pixels based on selected images
    func prefillPixelsIfPossible() {
        let targets: [ImageAsset]
        if newImages.isEmpty { targets = editedImages } else { targets = newImages }
        guard let first = (targets.first { $0.isEnabled }) ?? targets.first else { return }
        if let img = NSImage(contentsOf: first.workingURL) {
            let size = img.size
            let w = Int(size.width.rounded())
            let h = Int(size.height.rounded())
            let same = targets.filter { $0.isEnabled }.allSatisfy { asset in
                if let other = NSImage(contentsOf: asset.workingURL) {
                    return Int(other.size.width.rounded()) == w && Int(other.size.height.rounded()) == h
                }
                return false
            }
            if same { resizeWidth = String(w); resizeHeight = String(h) } else { resizeWidth = ""; resizeHeight = "" }
        }
    }

    // MARK: - Processing
    func buildPipeline() -> ProcessingPipeline {
        var pipeline = ProcessingPipeline()
        pipeline.overwriteOriginals = overwriteOriginals

        // Resize
        if sizeUnit == .percent, resizePercent != 1.0 {
            pipeline.add(ResizeOperation(mode: .percent(resizePercent)))
        } else if sizeUnit == .pixels, (Int(resizeWidth) != nil || Int(resizeHeight) != nil) {
            pipeline.add(ResizeOperation(mode: .pixels(width: Int(resizeWidth), height: Int(resizeHeight))))
        }

        // Convert
        if let fmt = selectedFormat { pipeline.add(ConvertOperation(format: fmt)); bumpRecentFormats(fmt) }

        // Compress
        switch compressionMode {
        case .percent: if compressionPercent < 0.999 { pipeline.add(CompressOperation(mode: .percent(compressionPercent), formatHint: selectedFormat ?? .jpeg)) }
        case .targetKB: if let kb = Int(compressionTargetKB), kb > 0 { pipeline.add(CompressOperation(mode: .targetKB(kb), formatHint: selectedFormat ?? .jpeg)) }
        }

        // Rotate
        if rotation != .r0 { pipeline.add(RotateOperation(rotation: rotation)) }

        // Flip
        if flipH { pipeline.add(FlipOperation(direction: .horizontal)) }
        if flipV { pipeline.add(FlipOperation(direction: .vertical)) }

        // Remove background
        if removeBackground { pipeline.add(RemoveBackgroundOperation()) }

        return pipeline
    }

    func applyPipeline() {
        let pipeline = buildPipeline()
        let targets: [ImageAsset]
        if newImages.isEmpty { targets = editedImages.filter { $0.isEnabled } }
        else { let enabledOld = editedImages.filter { $0.isEnabled }; targets = newImages.filter { $0.isEnabled } + enabledOld }

        var updatedNew: [ImageAsset] = newImages
        var updatedEdited: [ImageAsset] = editedImages

        for asset in targets {
            do {
                let updated = try pipeline.run(on: asset)
                if let idx = updatedNew.firstIndex(of: asset) { updatedNew.remove(at: idx); updatedEdited.append(updated) }
                else if let idx = updatedEdited.firstIndex(of: asset) { updatedEdited[idx] = updated }
                else { updatedEdited.append(updated) }
            } catch { print("Processing failed for \(asset.originalURL.lastPathComponent): \(error)") }
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.3)) { newImages = updatedNew; editedImages = updatedEdited }
    }

    // MARK: - Recovery
    func recoverOriginal(_ asset: ImageAsset) {
        guard let backup = asset.backupURL else { return }
        do {
            if FileManager.default.fileExists(atPath: asset.originalURL.path) { try FileManager.default.removeItem(at: asset.originalURL) }
            try FileManager.default.copyItem(at: backup, to: asset.originalURL)
            var updated = asset
            updated.workingURL = asset.originalURL
            updated.isEdited = false
            updated.thumbnail = ThumbnailGenerator.generateThumbnail(for: updated.workingURL)
            if let idx = editedImages.firstIndex(of: asset) { editedImages[idx] = updated }
        } catch { print("Recovery failed: \(error)") }
    }

    // MARK: - Pasteboard / Finder add
    func addFromPasteboard() {
        let pb = NSPasteboard.general
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] { addURLs(urls) }
        else if let images = pb.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage] {
            let dir = FileManager.default.temporaryDirectory
            var urls: [URL] = []
            for img in images {
                if let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let data = rep.representation(using: .png, properties: [:]) {
                    let url = dir.appendingPathComponent("paste_" + UUID().uuidString + ".png"); try? data.write(to: url); urls.append(url)
                }
            }
            addURLs(urls)
        }
    }

    func bumpRecentFormats(_ fmt: ImageFormat) {
        recentFormats.removeAll { $0 == fmt }
        recentFormats.insert(fmt, at: 0)
        if recentFormats.count > 3 { recentFormats = Array(recentFormats.prefix(3)) }
    }

    // MARK: - Clear all images
    func clearAll() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85, blendDuration: 0.3)) {
            newImages.removeAll()
            editedImages.removeAll()
        }
    }
} 