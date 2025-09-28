import Foundation
import AppKit
import SwiftUI
import OSLog

extension ImageToolsViewModel {
    nonisolated static let ingestionLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "image-tools", category: "Ingestion")
    func addURLs(_ urls: [URL]) {
        Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            await self.ingest(urls: urls)
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
        let targets: [ImageAsset] = images
        guard let first = (targets.first { $0.isEnabled }) ?? targets.first else { return }
        if let size = ImageMetadata.pixelSize(for: first.originalURL) {
            let w = Int(size.width.rounded())
            let h = Int(size.height.rounded())
            let same = targets.filter { $0.isEnabled }.allSatisfy { asset in
                if let other = ImageMetadata.pixelSize(for: asset.originalURL) {
                    return Int(other.width.rounded()) == w && Int(other.height.rounded()) == h
                }
                return false
            }
            if same {
                resizeWidth = String(w)
                resizeHeight = String(h)
            } else {
                resizeWidth = ""
                resizeHeight = ""
            }
        }
    }

    func bumpRecentFormats(_ fmt: ImageFormat) {
        recentFormats.removeAll { $0 == fmt }
        recentFormats.insert(fmt, at: 0)
        if recentFormats.count > 3 { recentFormats = Array(recentFormats.prefix(3)) }
    }

    private func ingest(urls: [URL]) async {
        let readable = urls
            .filter { ImageIOCapabilities.shared.isReadableURL($0) }
            .map { $0.standardizedFileURL }
        guard !readable.isEmpty else {
            Self.ingestionLogger.debug("Ingest skip: no readable URLs from \(urls.count, privacy: .public) inputs")
            return
        }

        Self.ingestionLogger.debug("Ingest start: \(readable.count, privacy: .public) readable URLs")

        let existing: Set<URL> = Set(images.map { $0.originalURL })
        let fresh = readable.filter { !existing.contains($0) }
        if let firstDir = fresh.first?.deletingLastPathComponent() {
            sourceDirectory = firstDir
        }

        guard !fresh.isEmpty else {
            Self.ingestionLogger.debug("Ingest skip: all URLs already present")
            return
        }

        Self.ingestionLogger.debug("Ingest new URLs: \(fresh.count, privacy: .public)")

        let assets: [ImageAsset] = fresh.map { ImageAsset(url: $0) }

        if !isIngesting {
            ingestCompleted = 0
            ingestTotal = 0
        }
        ingestTotal += fresh.count
        if ingestTotal > ingestCompleted {
            isIngesting = true
        }
        images.append(contentsOf: assets)
        Self.ingestionLogger.debug("Appended assets. Total images: \(self.images.count, privacy: .public)")

        let semaphore = AsyncSemaphore(value: 16)

        await withTaskGroup(of: Void.self) { group in
            for asset in assets {
                let fileName = asset.originalURL.lastPathComponent
                group.addTask(priority: .userInitiated) { [weak self] in
                    await semaphore.acquire()
                    guard let self else {
                        await semaphore.release()
                        return
                    }
                    Self.ingestionLogger.debug("Thumbnail load begin: \(fileName, privacy: .public)")
                    let output = await ThumbnailGenerator.shared.load(for: asset.originalURL)
                    Self.ingestionLogger.debug("Thumbnail load done: \(fileName, privacy: .public) thumb? \(output.thumbnail != nil) size? \(output.pixelSize != nil) bytes? \(output.fileSizeBytes != nil)")
                    await self.applyThumbnailUpdate(for: asset, output: output)
                    await self.incrementIngestionProgress()
                    await semaphore.release()
                }
            }
        }
        Self.ingestionLogger.debug("Ingest complete for batch of \(fresh.count, privacy: .public) URLs")
    }

    private func applyThumbnailUpdate(for asset: ImageAsset, output: ThumbnailGenerator.Output) {
        guard let idx = images.firstIndex(where: { $0.id == asset.id }) else {
            Self.ingestionLogger.warning("Thumbnail update skipped; asset missing: \(asset.originalURL.lastPathComponent, privacy: .public)")
            return
        }
        images[idx].thumbnail = output.thumbnail
        images[idx].originalPixelSize = output.pixelSize
        images[idx].originalFileSizeBytes = output.fileSizeBytes
        Self.ingestionLogger.debug("Thumbnail applied: \(asset.originalURL.lastPathComponent, privacy: .public)")
    }

    private func incrementIngestionProgress() {
        ingestCompleted = min(ingestCompleted + 1, ingestTotal)
        if ingestCompleted >= ingestTotal {
            isIngesting = false
        }
    }
}
