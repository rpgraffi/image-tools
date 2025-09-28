import Foundation
import AppKit
import UniformTypeIdentifiers

enum IngestionCoordinator {
    // MARK: - Helpers
    /// Returns the provider's registered type identifiers that conform to `public.image`.
    private static func imageTypeIdentifiers(for provider: NSItemProvider) -> [String] {
        provider.registeredTypeIdentifiers.filter { id in
            if let t = UTType(id) { return t.conforms(to: .image) }
            return false
        }
    }

    /// Returns the provider's registered type identifiers that represent directories/folders.
    private static func directoryTypeIdentifiers(for provider: NSItemProvider) -> [String] {
        provider.registeredTypeIdentifiers.filter { id in
            guard let t = UTType(id) else { return false }
            return t == .fileURL || t.conforms(to: .directory) || t.conforms(to: .folder)
        }
    }

    /// Writes a temporary PNG for a given `NSImage` and returns its file URL.
    private static func writeTempPNG(from image: NSImage, prefix: String = "paste_") -> URL? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:]) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(prefix + UUID().uuidString + ".png")
        try? data.write(to: url)
        return url
    }

    private static func loadFileURL(for provider: NSItemProvider, typeIdentifier: String) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadInPlaceFileRepresentation(forTypeIdentifier: typeIdentifier) { url, _, _ in
                continuation.resume(returning: url)
            }
        }
    }

    private static func loadData(for provider: NSItemProvider, typeIdentifier: String) async -> Data? {
        await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }

    /// Loads a usable file `URL` from an `NSItemProvider` representing an image.
    /// Strategy:
    /// 1) Try in-place file representation for concrete image UTIs
    /// 2) Try data representations for those UTIs and write a temp PNG
    /// 3) If none, try directory/fileURL representation (for Finder folder drops)
    private static func loadImageURL(from provider: NSItemProvider) async -> URL? {
        let imageIds = imageTypeIdentifiers(for: provider)

        for id in imageIds {
            if let url = await loadFileURL(for: provider, typeIdentifier: id) {
                return url
            }
        }

        for id in imageIds {
            if let data = await loadData(for: provider, typeIdentifier: id) {
                if let image = NSImage(data: data), let url = writeTempPNG(from: image) {
                    return url
                }
            }
        }

        for id in directoryTypeIdentifiers(for: provider) {
            if let url = await loadFileURL(for: provider, typeIdentifier: id) {
                return url
            }
        }

        return nil
    }
    /// Returns a flat list of readable image file URLs.
    /// - If `url` is a file and readable, it's returned as a single-element array.
    /// - If `url` is a directory, it is recursively enumerated and all readable files are returned.
    private static func collectSupportedFilesRecursively(at url: URL) -> [URL] {
        DirectoryEnumerator(url: url).collectSupportedImages()
    }

    private static func resolvedDirectory(for url: URL) -> URL? {
        guard url.isFileURL else { return nil }
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return url.standardizedFileURL
        }
        let parent = url.deletingLastPathComponent()
        return parent.path.isEmpty ? nil : parent.standardizedFileURL
    }

    /// Expands a file or directory `URL` into supported image file URLs.
    /// - If `url` is a directory, its contents are searched (recursively by default) and only readable image files are returned.
    /// - If `url` is a regular file, it is returned only if it's a readable image.
    /// - Non-image files are skipped.
    static func expandToSupportedImageURLs(from url: URL, recursive: Bool = true) -> [URL] {
        DirectoryEnumerator(url: url).collectSupportedImages()
    }
    static func canHandle(providers: [NSItemProvider]) -> Bool {
        providers.contains { provider in
            provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) ||
            provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) ||
            !directoryTypeIdentifiers(for: provider).isEmpty
        }
    }

    static func collectURLs(from providers: [NSItemProvider], completion: @escaping ([URL]) -> Void) {
        Task.detached(priority: .userInitiated) {
            let urls: [URL] = await withTaskGroup(of: [URL].self) { group in
                for provider in providers {
                    group.addTask {
                        if let url = await loadImageURL(from: provider) {
                            let token = SandboxAccessToken(url: url)
                            let expanded = DirectoryEnumerator(url: url).collectSupportedImages()

                            if let token {
                                SandboxAccessManager.shared.register(url: url, scopedToken: token)
                                token.stop()
                            }
                            return expanded
                        }
                        return []
                    }
                }

                var results: [URL] = []
                results.reserveCapacity(providers.count)

                for await expanded in group {
                    results.append(contentsOf: expanded)
                }
                return results
            }

            await MainActor.run {
                completion(urls)
            }
        }
    }

    static func collectURLsFromPasteboard(_ pasteboard: NSPasteboard = .general) -> [URL] {
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            // Expand any directories and filter to supported files only
            return urls.flatMap { DirectoryEnumerator(url: $0).collectSupportedImages() }
        }
        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage] {
            let dir = FileManager.default.temporaryDirectory
            var urls: [URL] = []
            for img in images {
                if let tiff = img.tiffRepresentation,
                   let rep = NSBitmapImageRep(data: tiff),
                   let data = rep.representation(using: .png, properties: [:]) {
                    let url = dir.appendingPathComponent("paste_" + UUID().uuidString + ".png")
                    try? data.write(to: url)
                    urls.append(url)
                }
            }
            return urls
        }
        return []
    }

    // MARK: - Swift Concurrency streaming ingestion
    /// Streams discovered URLs from the given item providers in small batches so the UI
    /// can update incrementally when many files are dropped/pasted.
    ///
    /// Uses Swift Concurrency primitives to yield batches as soon as they are ready.
    /// Reference: Swift Concurrency guide [Swift.org](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
    static func streamURLs(from providers: [NSItemProvider], batchSize: Int = 32) -> AsyncStream<[URL]> {
        AsyncStream { continuation in
            guard !providers.isEmpty else {
                continuation.finish()
                return
            }

            Task.detached(priority: .userInitiated) {
                var buffer: [URL] = []

                func flushBuffer(force: Bool = false) {
                    guard !buffer.isEmpty else { return }
                    if force || buffer.count >= batchSize {
                        let toYield = buffer
                        buffer.removeAll(keepingCapacity: true)
                        continuation.yield(toYield)
                    }
                }

                await withTaskGroup(of: [URL].self) { group in
                    for provider in providers {
                        group.addTask {
                                if let url = await loadImageURL(from: provider) {
                                    let token = SandboxAccessToken(url: url)
                            let expanded = DirectoryEnumerator(url: url).collectSupportedImages()

                                    if let token {
                                        SandboxAccessManager.shared.register(url: url, scopedToken: token)
                                        token.stop()
                                    }
                                    return expanded
                            }
                            return []
                        }
                    }

                    for await urls in group {
                        if urls.isEmpty { continue }
                        buffer.append(contentsOf: urls)
                        flushBuffer()
                    }
                }

                flushBuffer(force: true)
                continuation.finish()
            }
        }
    }

    static func presentOpenPanel(allowsDirectories: Bool = true,
                                 allowsMultiple: Bool = true,
                                 allowedContentTypes: [UTType] = [.image],
                                 completion: @escaping ([URL]) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = allowsMultiple
        panel.canChooseFiles = true
        panel.canChooseDirectories = allowsDirectories
        panel.allowedContentTypes = allowedContentTypes
        if panel.runModal() == .OK {
            // Expand any selected directories into supported image files
            let expanded: [URL] = panel.urls.flatMap { url in
                let standardized = url.standardizedFileURL
                SandboxAccessManager.shared.register(url: standardized)
                return expandToSupportedImageURLs(from: standardized, recursive: true)
            }
            completion(expanded)
        }
    }
} 