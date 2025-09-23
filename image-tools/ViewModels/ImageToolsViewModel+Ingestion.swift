import Foundation
import AppKit
import SwiftUI

extension ImageToolsViewModel {
    func addURLs(_ urls: [URL]) {
        let imageURLs = urls
            .filter { ImageIOCapabilities.shared.isReadableURL($0) }
            .map { $0.standardizedFileURL }
        guard !imageURLs.isEmpty else { return }

        // Create a simple one-shot stream in batches to reuse the unified ingestion path
        let batchSize = 16
        let stream = AsyncStream<[URL]> { continuation in
            Task {
                var startIndex = 0
                while startIndex < imageURLs.count {
                    let endIndex = min(startIndex + batchSize, imageURLs.count)
                    let batch = Array(imageURLs[startIndex..<endIndex])
                    continuation.yield(batch)
                    startIndex = endIndex
                    await Task.yield()
                }
                continuation.finish()
            }
        }
        ingestURLStream(stream)
    }

    func isSupportedImage(_ url: URL) -> Bool {
        ImageIOCapabilities.shared.isReadableURL(url)
    }

    // Remove an asset
    func remove(_ asset: ImageAsset) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.9, blendDuration: 0.2)) {
            if let idx = images.firstIndex(of: asset) { images.remove(at: idx) }
        }
    }

    // Prefill pixels based on selected images
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
            if same { resizeWidth = String(w); resizeHeight = String(h) } else { resizeWidth = ""; resizeHeight = "" }
        }
    }

    // Pasteboard / Finder add
    func addFromPasteboard() {
        let urls = IngestionCoordinator.collectURLsFromPasteboard()
        addURLs(urls)
    }

    // Streaming ingestion for drag & drop / paste providers
    func addProvidersStreaming(_ providers: [NSItemProvider], batchSize: Int = 32) {
        let stream = IngestionCoordinator.streamURLs(from: providers, batchSize: batchSize)
        ingestURLStream(stream)
    }

    // Unified incremental ingestion path for any stream of URL batches
    func ingestURLStream(_ stream: AsyncStream<[URL]>) {
        Task {
            for await urls in stream {
                // Pre-filter on a background context
                let readable = urls
                    .filter { ImageIOCapabilities.shared.isReadableURL($0) }
                    .map { $0.standardizedFileURL }
                guard !readable.isEmpty else { continue }

                // Read main-actor state needed for deduping and update source directory
                let fresh: [URL] = await MainActor.run {
                    let existing: Set<URL> = Set(images.map { $0.originalURL.standardizedFileURL })
                    let fresh = readable.filter { !existing.contains($0) }
                    if let firstDir = fresh.first?.deletingLastPathComponent() {
                        sourceDirectory = firstDir
                    }
                    return fresh
                }
                guard !fresh.isEmpty else { continue }

                // Build ImageAsset objects off the main actor with a high priority,
                // then append on the main actor to update the UI.
                await Task.detached(priority: .userInitiated) { [fresh] in
                    let assets = fresh.map { ImageAsset(url: $0) }
                    await MainActor.run {
                        self.images.append(contentsOf: assets)
                    }
                }.value
            }
        }
    }

    func bumpRecentFormats(_ fmt: ImageFormat) {
        recentFormats.removeAll { $0 == fmt }
        recentFormats.insert(fmt, at: 0)
        if recentFormats.count > 3 { recentFormats = Array(recentFormats.prefix(3)) }
    }
}


