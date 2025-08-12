import Foundation
import AppKit
import SwiftUI
import ImageIO

final class ImageToolsViewModel: ObservableObject {
    @Published var newImages: [ImageAsset] = []
    @Published var editedImages: [ImageAsset] = []

    @Published var overwriteOriginals: Bool = false
    // Persist selected export directory between sessions
    @Published var exportDirectory: URL? = nil { didSet { persistExportDirectory() } }
    // Last detected source directory from most recent import
    @Published var sourceDirectory: URL? = nil
    var isExportingToSource: Bool {
        guard let source = sourceDirectory?.standardizedFileURL else { return false }
        let export = exportDirectory?.standardizedFileURL
        return export == nil || export == source
    }

    // UI toggles/state
    @Published var sizeUnit: SizeUnitToggle = .percent
    @Published var resizePercent: Double = 1.0
    @Published var resizeWidth: String = ""
    @Published var resizeHeight: String = ""

    @Published var selectedFormat: ImageFormat? = nil { didSet { persistSelectedFormat(); onSelectedFormatChanged() } }
    @Published var allowedSquareSizes: [Int]? = nil
    @Published var restrictionHint: String? = nil

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

    // Estimated sizes per image (bytes); UI displays "--- KB" when nil/absent
    @Published var estimatedBytes: [UUID: Int] = [:]
    private var estimationTask: Task<Void, Never>? = nil

    // MARK: - Init / Persistence
    init() {
        loadPersistedState()
    }

    private enum PersistenceKeys {
        static let recentFormats = "image_tools.recent_formats.v1"
        static let selectedFormat = "image_tools.selected_format.v1"
        static let exportDirectory = "image_tools.export_directory.v1"
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
        if let exportPath = defaults.string(forKey: PersistenceKeys.exportDirectory) {
            exportDirectory = URL(fileURLWithPath: exportPath)
        }
        // Initialize restrictions after selectedFormat restoration
        updateRestrictions()
    }

    private func persistRecentFormats() { defaults.set(recentFormats.map { $0.id }, forKey: PersistenceKeys.recentFormats) }
    private func persistSelectedFormat() { defaults.set(selectedFormat?.id, forKey: PersistenceKeys.selectedFormat) }
    private func persistExportDirectory() {
        if let dir = exportDirectory {
            defaults.set(dir.path, forKey: PersistenceKeys.exportDirectory)
        } else {
            defaults.removeObject(forKey: PersistenceKeys.exportDirectory)
        }
    }

    private func updateRestrictions() {
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
            compressionTargetKB: compressionTargetKB,
            selectedFormat: selectedFormat
        )
    }

    // MARK: - True size estimation orchestration
    func triggerEstimationForVisible(_ visibleAssets: [ImageAsset]) {
        // Cancel previous run
        estimationTask?.cancel()
        let sizeUnit = self.sizeUnit
        let resizePercent = self.resizePercent
        let resizeWidth = self.resizeWidth
        let resizeHeight = self.resizeHeight
        let selectedFormat = self.selectedFormat
        let compressionMode = self.compressionMode
        let compressionPercent = self.compressionPercent
        let compressionTargetKB = self.compressionTargetKB
        let removeMetadata = self.removeMetadata

        estimationTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }
            let enabled = visibleAssets.filter { $0.isEnabled }
            let map = await TrueSizeEstimator.estimate(
                assets: enabled,
                sizeUnit: sizeUnit,
                resizePercent: resizePercent,
                resizeWidth: resizeWidth,
                resizeHeight: resizeHeight,
                selectedFormat: selectedFormat,
                compressionMode: compressionMode,
                compressionPercent: compressionPercent,
                compressionTargetKB: compressionTargetKB,
                removeMetadata: removeMetadata
            )
            await MainActor.run {
                self.estimatedBytes.merge(map) { _, new in new }
            }
        }
    }

    // React to format selection to prefill/switch resize inputs when required
    func onSelectedFormatChanged() {
        updateRestrictions()
        guard allowedSquareSizes != nil else { return }
        // Choose a reference size from first enabled asset
        let targets: [ImageAsset]
        if newImages.isEmpty { targets = editedImages } else { targets = newImages }
        guard let first = (targets.first { $0.isEnabled }) ?? targets.first else { return }
        let srcSize = ImageMetadata.pixelSize(for: first.workingURL) ?? first.originalPixelSize ?? .zero
        let caps = ImageIOCapabilities.shared
        if let fmt = selectedFormat, !caps.isValidPixelSize(srcSize, for: fmt.utType) {
            // Force pixel mode and prefill suggestion
            sizeUnit = .pixels
            if let side = caps.suggestedSquareSide(for: fmt.utType, source: srcSize) {
                resizeWidth = String(side)
                resizeHeight = String(side)
            }
        }
        // Also retrigger estimation when format changes
        scheduleReestimation()
    }

    // MARK: - Ingestion
    func addURLs(_ urls: [URL]) {
        let imageURLs = urls.filter { ImageIOCapabilities.shared.isReadableURL($0) }
        guard !imageURLs.isEmpty else { return }

        // Track source directory based on first image URL
        if let firstDir = imageURLs.first?.deletingLastPathComponent() {
            sourceDirectory = firstDir
        }

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
        // Trigger background estimation for newly added (visible set will drive actual selection in UI)
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

    // MARK: - Reactive estimation triggers
    private func scheduleReestimation() {
        // UI should call triggerEstimationForVisible with current viewport items; leave here as a hook if needed.
        // No-op: orchestrated from Views via onAppear/onChange with visible assets.
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
                if let firstDir = filtered.first?.deletingLastPathComponent() {
                    await MainActor.run {
                        sourceDirectory = firstDir
                    }
                }
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
        // Reset automatic source-based destination only if no explicit export directory is set
        if exportDirectory == nil {
            sourceDirectory = nil
        }
    }
} 