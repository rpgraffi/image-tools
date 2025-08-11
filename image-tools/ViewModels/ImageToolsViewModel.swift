import Foundation
import AppKit
import SwiftUI
import ImageIO

final class ImageToolsViewModel: ObservableObject {
    @Published var newImages: [ImageAsset] = []
    @Published var editedImages: [ImageAsset] = []

    @Published var overwriteOriginals: Bool = false
    @Published var exportDirectory: URL? = nil

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
    @Published var removeMetadata: Bool = false

    // Recently used formats for prioritization
    @Published var recentFormats: [ImageFormat] = [] { didSet { persistRecentFormats() } }

    // MARK: - Init / Persistence
    init() {
        loadPersistedState()
    }

    private enum PersistenceKeys {
        static let recentFormats = "image_tools.recent_formats.v1"
        static let selectedFormat = "image_tools.selected_format.v1"
    }

    private let defaults = UserDefaults.standard

    private func loadPersistedState() {
        if let raw = defaults.array(forKey: PersistenceKeys.recentFormats) as? [String] {
            let mapped = raw.compactMap { ImageIOCapabilities.shared.format(forIdentifier: $0) }
            if !mapped.isEmpty { recentFormats = Array(mapped.prefix(3)) }
        }
        if let selRaw = defaults.string(forKey: PersistenceKeys.selectedFormat),
           let fmt = ImageIOCapabilities.shared.format(forIdentifier: selRaw) {
            let caps = ImageIOCapabilities.shared
            if caps.supportsWriting(utType: fmt.utType) { selectedFormat = fmt }
        }
    }

    private func persistRecentFormats() { defaults.set(recentFormats.map { $0.id }, forKey: PersistenceKeys.recentFormats) }
    private func persistSelectedFormat() { defaults.set(selectedFormat?.id, forKey: PersistenceKeys.selectedFormat) }

    // MARK: - Preview calculations (reusable service-like helpers)
    func previewInfo(for asset: ImageAsset) -> PreviewInfo {
        PreviewEstimator().estimate(
            for: asset,
            sizeUnit: sizeUnit,
            resizePercent: resizePercent,
            resizeWidth: resizeWidth,
            resizeHeight: resizeHeight,
            compressionMode: compressionMode,
            compressionPercent: compressionPercent,
            compressionTargetKB: compressionTargetKB
        )
    }

    // MARK: - Ingestion
    func addURLs(_ urls: [URL]) {
        let imageURLs = urls.filter { ImageIOCapabilities.shared.isReadableURL($0) }
        guard !imageURLs.isEmpty else { return }

        // Append in batches to keep UI responsive
        let batchSize = 16
        Task { @MainActor in
            var startIndex = 0
            while startIndex < imageURLs.count {
                let endIndex = min(startIndex + batchSize, imageURLs.count)
                let batch = Array(imageURLs[startIndex..<endIndex])
                let assets = batch.map { ImageAsset(url: $0) }
                newImages.append(contentsOf: assets)
                startIndex = endIndex
                await Task.yield()
            }
        }
    }

    private func isSupportedImage(_ url: URL) -> Bool {
        ImageIOCapabilities.shared.isReadableURL(url)
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

    // Remove an asset from whichever list it is in
    func remove(_ asset: ImageAsset) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.9, blendDuration: 0.2)) {
            if let idx = newImages.firstIndex(of: asset) {
                newImages.remove(at: idx)
            } else if let idx = editedImages.firstIndex(of: asset) {
                editedImages.remove(at: idx)
            }
        }
    }

    // MARK: - Prefill pixels based on selected images
    func prefillPixelsIfPossible() {
        let targets: [ImageAsset]
        if newImages.isEmpty { targets = editedImages } else { targets = newImages }
        guard let first = (targets.first { $0.isEnabled }) ?? targets.first else { return }
        if let size = ImageMetadata.pixelSize(for: first.workingURL) {
            let w = Int(size.width.rounded())
            let h = Int(size.height.rounded())
            let same = targets.filter { $0.isEnabled }.allSatisfy { asset in
                if let other = ImageMetadata.pixelSize(for: asset.workingURL) {
                    return Int(other.width.rounded()) == w && Int(other.height.rounded()) == h
                }
                return false
            }
            if same { resizeWidth = String(w); resizeHeight = String(h) } else { resizeWidth = ""; resizeHeight = "" }
        }
    }

    // MARK: - Processing
    func buildPipeline() -> ProcessingPipeline {
        let pipeline = PipelineBuilder().build(
            sizeUnit: sizeUnit,
            resizePercent: resizePercent,
            resizeWidth: resizeWidth,
            resizeHeight: resizeHeight,
            selectedFormat: selectedFormat,
            compressionMode: compressionMode,
            compressionPercent: compressionPercent,
            compressionTargetKB: compressionTargetKB,
            flipH: flipH,
            flipV: flipV,
            removeBackground: removeBackground,
            overwriteOriginals: overwriteOriginals,
            removeMetadata: removeMetadata,
            exportDirectory: exportDirectory
        )
        if let fmt = selectedFormat { bumpRecentFormats(fmt) }
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
        let urls = IngestionCoordinator.collectURLsFromPasteboard()
        addURLs(urls)
    }

    // MARK: - Streaming ingestion for drag & drop / paste providers
    @MainActor
    func addProvidersStreaming(_ providers: [NSItemProvider], batchSize: Int = 32) {
        let stream = IngestionCoordinator.streamURLs(from: providers, batchSize: batchSize)
        Task {
            for await urls in stream {
                let filtered = urls.filter { ImageIOCapabilities.shared.isReadableURL($0) }
                guard !filtered.isEmpty else { continue }
                // Must create AppKit-backed assets on main actor
                await MainActor.run {
                    let assets = filtered.map { ImageAsset(url: $0) }
                    newImages.append(contentsOf: assets)
                }
            }
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