import Foundation
import AppKit
import OSLog

final class SandboxAccessToken {
    let url: URL
    private var stopHandler: (() -> Void)?

    init?(url: URL) {
        guard url.isFileURL else { return nil }
        let standardized = url.standardizedFileURL
        if standardized.startAccessingSecurityScopedResource() {
            stopHandler = {
                standardized.stopAccessingSecurityScopedResource()
            }
        }
        self.url = standardized
    }

    func stop() {
        stopHandler?()
        stopHandler = nil
    }

    deinit {
        stop()
    }
}

final class SandboxAccessManager {
    static let shared = SandboxAccessManager()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "image-tools", category: "Sandbox")
    private let defaultsKey = "sandbox.bookmarks.directories.v1"
    private let queue = DispatchQueue(label: "com.image-tools.sandbox")

    private var bookmarks: [String: Data]

    private init() {
        if let stored = UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: Data] {
            bookmarks = stored
        } else {
            bookmarks = [:]
        }
    }

    func hasBookmark(for directory: URL) -> Bool {
        bookmarkData(for: directory) != nil
    }

    func beginAccess(for directory: URL) -> SandboxAccessToken? {
        let dir = directory.standardizedFileURL

        if isInsideAppContainer(dir) {
            return SandboxAccessToken(url: dir)
        }

        guard let data = bookmarkData(for: dir) else {
            return nil
        }

        do {
            var isStale = false
            let resolved = try URL(resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &isStale)
            if isStale {
                try refreshBookmark(for: dir, resolvedURL: resolved)
            }
            return SandboxAccessToken(url: resolved)
        } catch {
            logger.error("Failed to resolve bookmark for \(dir.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            removeBookmark(for: dir)
            return nil
        }
    }

    func canAccess(_ directory: URL) -> Bool {
        guard let token = beginAccess(for: directory) else { return false }
        token.stop()
        return true
    }

    func register(url: URL, scopedToken: SandboxAccessToken? = nil) {
        guard let directory = directoryURL(for: url) else { return }
        if hasBookmark(for: directory) || isInsideAppContainer(directory) { return }

        if let provided = scopedToken {
            if provided.url.standardizedFileURL == directory {
                storeBookmark(for: directory, using: provided)
                return
            }
            if provided.url.deletingLastPathComponent().standardizedFileURL == directory,
               let upgraded = SandboxAccessToken(url: directory) {
                storeBookmark(for: directory, using: upgraded)
                upgraded.stop()
                return
            }
        }

        if let directToken = SandboxAccessToken(url: directory) {
            storeBookmark(for: directory, using: directToken)
            directToken.stop()
        }
    }

    @MainActor
    @discardableResult
    func requestAccessIfNeeded(to directory: URL, message: String?) async -> Bool {
        let dir = directory.standardizedFileURL
        if canAccess(dir) { return true }

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = String(localized: "Allow")
        panel.message = message ?? String(localized: "Allow access to this folder.")
        panel.directoryURL = dir

        let result = panel.runModal()
        if result == .OK, let chosen = panel.urls.first {
            register(url: chosen)
        }

        return canAccess(dir)
    }

    func removeBookmark(for directory: URL) {
        let key = key(for: directory)
        queue.sync {
            if bookmarks.removeValue(forKey: key) != nil {
                UserDefaults.standard.set(bookmarks, forKey: defaultsKey)
                logger.debug("Removed bookmark for \(directory.standardizedFileURL.path, privacy: .public)")
            }
        }
    }

    // MARK: - Helpers

    private func directoryURL(for url: URL) -> URL? {
        let standardized = url.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: standardized.path, isDirectory: &isDirectory) else { return nil }
        if isDirectory.boolValue {
            return standardized
        }
        let parent = standardized.deletingLastPathComponent()
        return parent.path.isEmpty ? nil : parent.standardizedFileURL
    }

    private func key(for directory: URL) -> String {
        directory.standardizedFileURL.resolvingSymlinksInPath().path
    }

    private func bookmarkData(for directory: URL) -> Data? {
        let key = key(for: directory)
        return queue.sync { bookmarks[key] }
    }

    private func storeBookmark(for directory: URL, using token: SandboxAccessToken) {
        do {
            let data = try directory.standardizedFileURL.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
            saveBookmark(data, for: directory)
            logger.debug("Stored bookmark for \(directory.path, privacy: .public)")
        } catch {
            logger.error("Bookmark creation failed for \(directory.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func saveBookmark(_ data: Data, for directory: URL) {
        let key = key(for: directory)
        queue.sync {
            bookmarks[key] = data
            UserDefaults.standard.set(bookmarks, forKey: defaultsKey)
        }
    }

    private func refreshBookmark(for directory: URL, resolvedURL: URL) throws {
        let data = try resolvedURL.standardizedFileURL.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        saveBookmark(data, for: directory)
        logger.debug("Refreshed stale bookmark for \(directory.path, privacy: .public)")
    }

    private func isInsideAppContainer(_ url: URL) -> Bool {
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        return url.standardizedFileURL.path.hasPrefix(home.path)
    }
}


