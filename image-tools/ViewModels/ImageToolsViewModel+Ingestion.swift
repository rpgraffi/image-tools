import Foundation
import AppKit
import SwiftUI
import OSLog

extension ImageToolsViewModel {
    nonisolated static let ingestionLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "image-tools", category: "Ingestion")
    func addURLs(_ urls: [URL]) {
        Task(priority: .userInitiated) { [weak self] in
            await self?.ingest(urls: urls)
        }
    }

    func addProvidersStreaming(_ providers: [NSItemProvider], batchSize: Int = 64) {
        Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let stream = IngestionCoordinator.streamURLs(from: providers, batchSize: batchSize)
            for await urls in stream {
                await self.ingest(urls: urls)
            }
        }
    }

    func ingestURLStream(_ stream: AsyncStream<[URL]>) {
        Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            for await urls in stream {
                await self.ingest(urls: urls)
            }
        }
    }

    func addFromPasteboard() {
        let urls = IngestionCoordinator.collectURLsFromPasteboard()
        addURLs(urls)
    }

    func isSupportedImage(_ url: URL) -> Bool {
        ImageIOCapabilities.shared.isReadableURL(url)
    }

    func remove(_ asset: ImageAsset) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.9, blendDuration: 0.2)) {
            if let idx = images.firstIndex(of: asset) { images.remove(at: idx) }
        }
    }

    func prefillPixelsIfPossible() {
        guard let firstAsset = images.first,
              let firstSize = ImageMetadata.pixelSize(for: firstAsset.originalURL) else {
            return
        }
        
        let targetSize = (width: Int(firstSize.width.rounded()), height: Int(firstSize.height.rounded()))
        
        let allSameSize = images.allSatisfy { asset in
            guard let size = ImageMetadata.pixelSize(for: asset.originalURL) else {
                return false
            }
            return Int(size.width.rounded()) == targetSize.width &&
                   Int(size.height.rounded()) == targetSize.height
        }
        
        if allSameSize {
            resizeWidth = String(targetSize.width)
            resizeHeight = String(targetSize.height)
        } else {
            resizeWidth = ""
            resizeHeight = ""
        }
    }

    func bumpRecentFormats(_ format: ImageFormat) {
        recentFormats.removeAll { $0 == format }
        recentFormats.insert(format, at: 0)
        if recentFormats.count > 3 {
            recentFormats = Array(recentFormats.prefix(3))
        }
    }
    
    // MARK: - Private Methods

    private func ingest(urls: [URL]) async {
        let readableURLs = filterReadableURLs(from: urls)
        guard !readableURLs.isEmpty else {
            Self.ingestionLogger.debug("Ingest skip: no readable URLs from \(urls.count, privacy: .public) inputs")
            return
        }

        Self.ingestionLogger.debug("Ingest start: \(readableURLs.count, privacy: .public) readable URLs")

        let newURLs = filterNewURLs(from: readableURLs)
        guard !newURLs.isEmpty else {
            Self.ingestionLogger.debug("Ingest skip: all URLs already present")
            return
        }

        Self.ingestionLogger.debug("Ingest new URLs: \(newURLs.count, privacy: .public)")
        
        updateSourceDirectory(from: newURLs)
        let newAssets = newURLs.map { ImageAsset(url: $0) }
        prepareIngestionState(for: newAssets.count)
        images.append(contentsOf: newAssets)
        
        Self.ingestionLogger.debug("Appended assets. Total images: \(self.images.count, privacy: .public)")

        await loadThumbnails(for: newAssets)
        Self.ingestionLogger.debug("Ingest complete for batch of \(newURLs.count, privacy: .public) URLs")
    }
    
    private func filterReadableURLs(from urls: [URL]) -> [URL] {
        urls
            .filter { ImageIOCapabilities.shared.isReadableURL($0) }
            .map { $0.standardizedFileURL }
    }
    
    private func filterNewURLs(from urls: [URL]) -> [URL] {
        let existingURLs = Set(images.map { $0.originalURL })
        return urls.filter { !existingURLs.contains($0) }
    }
    
    private func updateSourceDirectory(from urls: [URL]) {
        if let firstDirectory = urls.first?.deletingLastPathComponent() {
            sourceDirectory = firstDirectory
        }
    }
    
    private func prepareIngestionState(for count: Int) {
        if !isIngesting {
            ingestCompleted = 0
            ingestTotal = 0
        }
        ingestTotal += count
        if ingestTotal > ingestCompleted {
            isIngesting = true
        }
    }
    
    private func loadThumbnails(for assets: [ImageAsset]) async {
        let semaphore = AsyncSemaphore(value: 16)

        await withTaskGroup(of: Void.self) { group in
            for asset in assets {
                group.addTask(priority: .userInitiated) { [weak self] in
                    await self?.loadThumbnail(for: asset, semaphore: semaphore)
                }
            }
        }
    }
    
    private func loadThumbnail(for asset: ImageAsset, semaphore: AsyncSemaphore) async {
        await semaphore.acquire()
        defer { Task { await semaphore.release() } }
        
        let fileName = asset.originalURL.lastPathComponent
        Self.ingestionLogger.debug("Thumbnail load begin: \(fileName, privacy: .public)")
        
        let output = await ThumbnailGenerator.load(for: asset.originalURL)
        
        Self.ingestionLogger.debug("""
            Thumbnail load done: \(fileName, privacy: .public) \
            thumb? \(output.thumbnail != nil) \
            size? \(output.pixelSize != nil) \
            bytes? \(output.fileSizeBytes != nil)
            """)
        
        applyThumbnailUpdate(for: asset, output: output)
        incrementIngestionProgress()
    }

    private func applyThumbnailUpdate(for asset: ImageAsset, output: ThumbnailGenerator.Output) {
        guard let index = images.firstIndex(where: { $0.id == asset.id }) else {
            Self.ingestionLogger.warning("""
                Thumbnail update skipped; asset missing: \
                \(asset.originalURL.lastPathComponent, privacy: .public)
                """)
            return
        }
        
        images[index].thumbnail = output.thumbnail
        images[index].originalPixelSize = output.pixelSize
        images[index].originalFileSizeBytes = output.fileSizeBytes
        
        Self.ingestionLogger.debug("Thumbnail applied: \(asset.originalURL.lastPathComponent, privacy: .public)")
    }

    private func incrementIngestionProgress() {
        ingestCompleted = min(ingestCompleted + 1, ingestTotal)
        if ingestCompleted >= ingestTotal {
            isIngesting = false
        }
    }
}
