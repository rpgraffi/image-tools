import Foundation
import AppKit
import SwiftUI

extension ImageToolsViewModel {
    func addURLs(_ urls: [URL]) {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            await self.ingest(urls: urls)
        }
    }

    func addProvidersStreaming(_ providers: [NSItemProvider], batchSize: Int = 64) {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let stream = IngestionCoordinator.streamURLs(from: providers, batchSize: batchSize)
            for await urls in stream {
                await self.ingest(urls: urls)
            }
        }
    }

    func ingestURLStream(_ stream: AsyncStream<[URL]>) {
        Task.detached(priority: .userInitiated) { [weak self] in
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
        guard !readable.isEmpty else { return }

        let fresh: [URL] = await MainActor.run {
            let existing: Set<URL> = Set(images.map { $0.originalURL })
            let fresh = readable.filter { !existing.contains($0) }
            if let firstDir = fresh.first?.deletingLastPathComponent() {
                sourceDirectory = firstDir
            }
            return fresh
        }

        guard !fresh.isEmpty else { return }

        let outputs: [Int: ThumbnailGenerator.Output] = await withTaskGroup(of: (Int, ThumbnailGenerator.Output).self) { group in
            for (index, url) in fresh.enumerated() {
                group.addTask {
                    let output = await ThumbnailGenerator.shared.load(for: url)
                    return (index, output)
                }
            }

            var result: [Int: ThumbnailGenerator.Output] = [:]
            result.reserveCapacity(fresh.count)

            for await (index, output) in group {
                result[index] = output
            }

            return result
        }

        await MainActor.run {
            for (index, url) in fresh.enumerated() {
                var asset = ImageAsset(url: url)
                if let output = outputs[index] {
                    asset.thumbnail = output.thumbnail
                    asset.originalPixelSize = output.pixelSize
                    asset.originalFileSizeBytes = output.fileSizeBytes
                }
                images.append(asset)
            }
        }
    }
}

