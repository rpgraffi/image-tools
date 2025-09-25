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

    /// Loads a usable file `URL` from an `NSItemProvider` representing an image.
    /// Strategy:
    /// 1) Try in-place file representation for concrete image UTIs
    /// 2) Try data representations for those UTIs and write a temp PNG
    /// 3) If none, try directory/fileURL representation (for Finder folder drops)
    private static func loadImageURL(from provider: NSItemProvider, completion: @escaping (URL?) -> Void) {
        let imageIds = imageTypeIdentifiers(for: provider)

        func tryInPlace(_ index: Int) {
            guard index < imageIds.count else { return tryData(0) }
            provider.loadInPlaceFileRepresentation(forTypeIdentifier: imageIds[index]) { url, _, _ in
                if let url = url { completion(url) }
                else { tryInPlace(index + 1) }
            }
        }

        func tryData(_ index: Int) {
            guard index < imageIds.count else {
                // Attempt to resolve a directory/folder URL
                let dirIds = directoryTypeIdentifiers(for: provider)
                if let first = dirIds.first {
                    provider.loadInPlaceFileRepresentation(forTypeIdentifier: first) { url, _, _ in
                        completion(url)
                    }
                } else {
                    completion(nil)
                }
                return
            }
            provider.loadDataRepresentation(forTypeIdentifier: imageIds[index]) { data, _ in
                if let data = data, let image = NSImage(data: data), let url = writeTempPNG(from: image) {
                    completion(url)
                } else {
                    tryData(index + 1)
                }
            }
        }

        if !imageIds.isEmpty { tryInPlace(0) }
        else if let first = directoryTypeIdentifiers(for: provider).first {
            provider.loadInPlaceFileRepresentation(forTypeIdentifier: first) { url, _, _ in
                completion(url)
            }
        } else {
            completion(nil)
        }
    }
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
            provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) ||
            provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) ||
            !directoryTypeIdentifiers(for: provider).isEmpty
        }
    }

    static func collectURLs(from providers: [NSItemProvider], completion: @escaping ([URL]) -> Void) {
        let group = DispatchGroup()
        var urls: [URL] = []
        let urlsLock = NSLock()

        for provider in providers {
            group.enter()
            loadImageURL(from: provider) { url in
                if let url = url {
                    var didAccess = false
                    if url.isFileURL { didAccess = url.startAccessingSecurityScopedResource() }
                    let expanded = collectSupportedFilesRecursively(at: url)
                    if didAccess { url.stopAccessingSecurityScopedResource() }
                    if !expanded.isEmpty { urlsLock.lock(); urls.append(contentsOf: expanded); urlsLock.unlock() }
                }
                group.leave()
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
                lock.lock(); pendingLoads += 1; lock.unlock()
                loadImageURL(from: provider) { url in
                    if let url = url {
                        var didAccess = false
                        if url.isFileURL { didAccess = url.startAccessingSecurityScopedResource() }
                        let expanded = collectSupportedFilesRecursively(at: url)
                        if didAccess { url.stopAccessingSecurityScopedResource() }
                        for file in expanded { appendURL(file) }
                    }
                    decrementAndFinishIfDone()
                }
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
                expandToSupportedImageURLs(from: url, recursive: true)
            }
            completion(expanded)
        }
    }
} 