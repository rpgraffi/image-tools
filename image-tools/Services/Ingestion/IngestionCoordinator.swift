import Foundation
import AppKit
import UniformTypeIdentifiers

enum IngestionCoordinator {
    // MARK: - Helpers
    /// Returns a flat list of readable image file URLs.
    /// - If `url` is a file and readable, it's returned as a single-element array.
    /// - If `url` is a directory, it is recursively enumerated and all readable files are returned.
    private static func collectSupportedFilesRecursively(at url: URL) -> [URL] {
        guard url.isFileURL else { return [] }

        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        guard exists else { return [] }

        if !isDirectory.boolValue {
            return ImageIOCapabilities.shared.isReadableURL(url) ? [url] : []
        }

        // Enumerate directory contents recursively, skipping packages and hidden files
        var results: [URL] = []
        let keys: [URLResourceKey] = [.isRegularFileKey]
        if let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsPackageDescendants, .skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) {
            for case let fileURL as URL in enumerator {
                // Fast path: only consider regular files
                if let values = try? fileURL.resourceValues(forKeys: Set(keys)), values.isRegularFile == true {
                    if ImageIOCapabilities.shared.isReadableURL(fileURL) {
                        results.append(fileURL)
                    }
                }
            }
        }
        return results
    }

    /// Expands a file or directory `URL` into supported image file URLs.
    /// - If `url` is a directory, its contents are searched (recursively by default) and only readable image files are returned.
    /// - If `url` is a regular file, it is returned only if it's a readable image.
    /// - Non-image files are skipped.
    static func expandToSupportedImageURLs(from url: URL, recursive: Bool = true) -> [URL] {
        var results: [URL] = []
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
            if recursive {
                return collectSupportedFilesRecursively(at: url)
            } else {
                let keys: [URLResourceKey] = [.isRegularFileKey]
                if let items = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) {
                    for fileURL in items {
                        var isChildDir: ObjCBool = false
                        if fileManager.fileExists(atPath: fileURL.path, isDirectory: &isChildDir), !isChildDir.boolValue,
                           ImageIOCapabilities.shared.isReadableURL(fileURL) {
                            results.append(fileURL)
                        }
                    }
                }
            }
        } else {
            if ImageIOCapabilities.shared.isReadableURL(url) {
                results.append(url)
            }
        }
        return results
    }
    static func canHandle(providers: [NSItemProvider]) -> Bool {
        providers.contains { provider in
            provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) ||
            provider.hasItemConformingToTypeIdentifier(UTType.image.identifier)
        }
    }

    static func collectURLs(from providers: [NSItemProvider], completion: @escaping ([URL]) -> Void) {
        let group = DispatchGroup()
        var urls: [URL] = []
        let urlsLock = NSLock()

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    let maybeURL: URL? = {
                        if let data = item as? Data { return URL(dataRepresentation: data, relativeTo: nil) }
                        if let url = item as? URL { return url }
                        return nil
                    }()
                    if let url = maybeURL {
                        let expanded = collectSupportedFilesRecursively(at: url)
                        if !expanded.isEmpty { urlsLock.lock(); urls.append(contentsOf: expanded); urlsLock.unlock() }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    let tempDir = FileManager.default.temporaryDirectory
                    func writeImage(_ nsImage: NSImage) {
                        if let tiff = nsImage.tiffRepresentation,
                           let rep = NSBitmapImageRep(data: tiff),
                           let data = rep.representation(using: .png, properties: [:]) {
                            let url = tempDir.appendingPathComponent("paste_" + UUID().uuidString + ".png")
                            try? data.write(to: url)
                            urlsLock.lock(); urls.append(url); urlsLock.unlock()
                        }
                    }
                    if let data = item as? Data, let image = NSImage(data: data) {
                        writeImage(image)
                    } else if let image = item as? NSImage {
                        writeImage(image)
                    }
                }
            }
        }

        group.notify(queue: .main) {
            completion(urls)
        }
    }

    static func collectURLsFromPasteboard(_ pasteboard: NSPasteboard = .general) -> [URL] {
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            // Expand any directories and filter to supported files only
            return urls.flatMap { collectSupportedFilesRecursively(at: $0) }
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
            // If nothing to do, finish immediately
            guard !providers.isEmpty else {
                continuation.finish()
                return
            }

            let lock = NSLock()
            var pendingLoads: Int = 0
            var buffer: [URL] = []

            func yieldBufferIfNeeded(force: Bool = false) {
                let shouldYield = force || buffer.count >= batchSize
                guard shouldYield, !buffer.isEmpty else { return }
                let toYield = buffer
                buffer.removeAll(keepingCapacity: true)
                continuation.yield(toYield)
            }

            func appendURL(_ url: URL) {
                lock.lock()
                buffer.append(url)
                yieldBufferIfNeeded()
                lock.unlock()
            }

            func decrementAndFinishIfDone() {
                var shouldFinish = false
                var trailing: [URL] = []
                lock.lock()
                pendingLoads -= 1
                if pendingLoads == 0 {
                    shouldFinish = true
                    trailing = buffer
                    buffer.removeAll(keepingCapacity: false)
                }
                lock.unlock()
                if !trailing.isEmpty { continuation.yield(trailing) }
                if shouldFinish { continuation.finish() }
            }

            // Schedule loads for each provider
            for provider in providers {
                if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    lock.lock(); pendingLoads += 1; lock.unlock()
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                        defer { decrementAndFinishIfDone() }
                        let maybeURL: URL? = {
                            if let data = item as? Data { return URL(dataRepresentation: data, relativeTo: nil) }
                            if let url = item as? URL { return url }
                            return nil
                        }()
                        if let url = maybeURL {
                            let expanded = collectSupportedFilesRecursively(at: url)
                            for file in expanded { appendURL(file) }
                        }
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    lock.lock(); pendingLoads += 1; lock.unlock()
                    provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, _ in
                        defer { decrementAndFinishIfDone() }
                        func writeImage(_ nsImage: NSImage) -> URL? {
                            guard let tiff = nsImage.tiffRepresentation,
                                  let rep = NSBitmapImageRep(data: tiff),
                                  let data = rep.representation(using: .png, properties: [:]) else { return nil }
                            let url = FileManager.default.temporaryDirectory.appendingPathComponent("paste_" + UUID().uuidString + ".png")
                            try? data.write(to: url)
                            return url
                        }
                        if let data = item as? Data, let image = NSImage(data: data), let url = writeImage(image) {
                            appendURL(url)
                        } else if let image = item as? NSImage, let url = writeImage(image) {
                            appendURL(url)
                        }
                    }
                }
            }
        }
    }

    static func presentOpenPanel(allowsDirectories: Bool = false,
                                 allowsMultiple: Bool = true,
                                 allowedContentTypes: [UTType] = [.image],
                                 completion: @escaping ([URL]) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = allowsMultiple
        panel.canChooseFiles = true
        panel.canChooseDirectories = allowsDirectories
        panel.allowedContentTypes = allowedContentTypes
        if panel.runModal() == .OK {
            completion(panel.urls)
        }
    }
} 