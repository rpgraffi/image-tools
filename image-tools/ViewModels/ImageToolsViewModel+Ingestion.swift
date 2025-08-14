import Foundation
import AppKit
import SwiftUI

extension ImageToolsViewModel {
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
                images.append(contentsOf: assets)
                startIndex = endIndex
                await Task.yield()
            }
        }
        // Trigger background estimation for newly added (visible set will drive actual selection in UI)
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
                    images.append(contentsOf: assets)
                }
            }
        }
    }

    func bumpRecentFormats(_ fmt: ImageFormat) {
        recentFormats.removeAll { $0 == fmt }
        recentFormats.insert(fmt, at: 0)
        if recentFormats.count > 3 { recentFormats = Array(recentFormats.prefix(3)) }
    }
}


