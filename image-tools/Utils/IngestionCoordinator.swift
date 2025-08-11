import Foundation
import AppKit
import UniformTypeIdentifiers

enum IngestionCoordinator {
    static func canHandle(providers: [NSItemProvider]) -> Bool {
        providers.contains { provider in
            provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) ||
            provider.hasItemConformingToTypeIdentifier(UTType.image.identifier)
        }
    }

    static func collectURLs(from providers: [NSItemProvider], completion: @escaping ([URL]) -> Void) {
        let group = DispatchGroup()
        var urls: [URL] = []

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        urls.append(url)
                    } else if let url = item as? URL {
                        urls.append(url)
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
                            urls.append(url)
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
            return urls
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
                        if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                            appendURL(url)
                        } else if let url = item as? URL {
                            appendURL(url)
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