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