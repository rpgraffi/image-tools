import Foundation
import AppKit
import UniformTypeIdentifiers

enum IngestionCoordinator {
    // MARK: - Public API
    
    /// Determines if any of the provided item providers can be handled by this coordinator.
    static func canHandle(providers: [NSItemProvider]) -> Bool {
        providers.contains { provider in
            provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) ||
            provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) ||
            !directoryTypeIdentifiers(for: provider).isEmpty
        }
    }
    
    /// Expands a file or directory URL into supported image file URLs.
    /// - Parameter url: The file or directory URL to expand
    /// - Returns: Array of supported image file URLs
    static func expandToSupportedImageURLs(from url: URL) -> [URL] {
        DirectoryEnumerator(url: url).collectSupportedImages()
    }
    
    /// Collects URLs from item providers asynchronously.
    /// - Parameters:
    ///   - providers: The item providers to process
    ///   - completion: Called on the main actor with the collected URLs
    static func collectURLs(from providers: [NSItemProvider], completion: @escaping ([URL]) -> Void) {
        Task.detached(priority: .userInitiated) {
            let urls = await processProviders(providers)
            await MainActor.run {
                completion(urls)
            }
        }
    }
    
    /// Streams discovered URLs from item providers in batches for incremental UI updates.
    /// - Parameters:
    ///   - providers: The item providers to process
    ///   - batchSize: Number of URLs to accumulate before yielding a batch (default: 32)
    /// - Returns: AsyncStream that yields batches of URLs
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
                            await processProvider(provider)
                        }
                    }
                    
                    for await urls in group {
                        guard !urls.isEmpty else { continue }
                        buffer.append(contentsOf: urls)
                        flushBuffer()
                    }
                }
                
                flushBuffer(force: true)
                continuation.finish()
            }
        }
    }
    
    /// Collects URLs from the pasteboard, handling both file URLs and pasted images.
    /// - Parameter pasteboard: The pasteboard to read from (defaults to general pasteboard)
    /// - Returns: Array of image file URLs
    static func collectURLsFromPasteboard(_ pasteboard: NSPasteboard = .general) -> [URL] {
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            return urls.flatMap { DirectoryEnumerator(url: $0).collectSupportedImages() }
        }
        
        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage] {
            return images.compactMap { writeTempPNG(from: $0) }
        }
        
        return []
    }
    
    /// Presents a system open panel for selecting image files or directories.
    /// - Parameters:
    ///   - allowsDirectories: Whether directories can be selected
    ///   - allowsMultiple: Whether multiple items can be selected
    ///   - allowedContentTypes: Allowed file types (defaults to images only)
    ///   - completion: Called with the selected and expanded URLs
    static func presentOpenPanel(
        allowsDirectories: Bool = true,
        allowsMultiple: Bool = true,
        allowedContentTypes: [UTType] = [.image],
        completion: @escaping ([URL]) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = allowsMultiple
        panel.canChooseFiles = true
        panel.canChooseDirectories = allowsDirectories
        panel.allowedContentTypes = allowedContentTypes
        
        guard panel.runModal() == .OK else { return }
        
        let expanded: [URL] = panel.urls.flatMap { url in
            let standardized = url.standardizedFileURL
            SandboxAccessManager.shared.register(url: standardized)
            return expandToSupportedImageURLs(from: standardized)
        }
        completion(expanded)
    }
    
    // MARK: - Private Helpers
    
    /// Processes multiple providers concurrently and returns all discovered URLs.
    private static func processProviders(_ providers: [NSItemProvider]) async -> [URL] {
        await withTaskGroup(of: [URL].self) { group in
            for provider in providers {
                group.addTask {
                    await processProvider(provider)
                }
            }
            
            var results: [URL] = []
            results.reserveCapacity(providers.count)
            
            for await urls in group {
                results.append(contentsOf: urls)
            }
            return results
        }
    }
    
    /// Processes a single provider and returns discovered image URLs.
    private static func processProvider(_ provider: NSItemProvider) async -> [URL] {
        guard let url = await loadImageURL(from: provider) else {
            return []
        }
        
        return withSandboxAccess(to: url) {
            DirectoryEnumerator(url: url).collectSupportedImages()
        }
    }
    
    /// Executes a closure with sandbox access to the given URL.
    @discardableResult
    private static func withSandboxAccess<T>(to url: URL, _ closure: () -> T) -> T {
        let token = SandboxAccessToken(url: url)
        defer {
            if let token {
                SandboxAccessManager.shared.register(url: url, scopedToken: token)
                token.stop()
            }
        }
        return closure()
    }
    
    // MARK: - Type Identification
    
    /// Returns the provider's registered type identifiers that conform to `public.image`.
    private static func imageTypeIdentifiers(for provider: NSItemProvider) -> [String] {
        provider.registeredTypeIdentifiers.filter { id in
            if let type = UTType(id) {
                return type.conforms(to: .image)
            }
            return false
        }
    }
    
    /// Returns the provider's registered type identifiers that represent directories/folders.
    private static func directoryTypeIdentifiers(for provider: NSItemProvider) -> [String] {
        provider.registeredTypeIdentifiers.filter { id in
            guard let type = UTType(id) else { return false }
            return type == .fileURL || type.conforms(to: .directory) || type.conforms(to: .folder)
        }
    }
    
    // MARK: - URL Loading
    
    /// Loads a usable file URL from an NSItemProvider representing an image.
    /// - Strategy:
    ///   1. Try in-place file representation for concrete image UTIs
    ///   2. Try data representations and write a temporary PNG
    ///   3. Try directory/fileURL representation (for Finder folder drops)
    private static func loadImageURL(from provider: NSItemProvider) async -> URL? {
        let imageIds = imageTypeIdentifiers(for: provider)
        
        // Try in-place file representation
        for id in imageIds {
            if let url = await loadFileURL(for: provider, typeIdentifier: id) {
                return url
            }
        }
        
        // Try data representation
        for id in imageIds {
            if let data = await loadData(for: provider, typeIdentifier: id),
               let image = NSImage(data: data),
               let url = writeTempPNG(from: image) {
                return url
            }
        }
        
        // Try directory representation
        for id in directoryTypeIdentifiers(for: provider) {
            if let url = await loadFileURL(for: provider, typeIdentifier: id) {
                return url
            }
        }
        
        return nil
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
    
    // MARK: - Image Conversion
    
    /// Writes a temporary PNG file for the given NSImage.
    /// - Parameters:
    ///   - image: The image to convert
    ///   - prefix: Filename prefix (default: "paste_")
    /// - Returns: URL of the temporary PNG file, or nil if conversion failed
    private static func writeTempPNG(from image: NSImage, prefix: String = "paste_") -> URL? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:]) else {
            return nil
        }
        
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(prefix + UUID().uuidString + ".png")
        
        try? data.write(to: url)
        return url
    }
} 