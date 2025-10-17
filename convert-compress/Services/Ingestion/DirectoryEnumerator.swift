import Foundation

struct DirectoryEnumerator {
    let url: URL
    var fileManager: FileManager = .default

    func collectSupportedImages() -> [URL] {
        guard url.isFileURL else { return [] }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return [] }

        if !isDirectory.boolValue {
            return ImageIOCapabilities.shared.isReadableURL(url) ? [url.standardizedFileURL] : []
        }

        return enumerateRecursively(at: url)
    }

    private func enumerateRecursively(at directory: URL) -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey]
        guard let enumerator = fileManager.enumerator(at: directory,
                                                      includingPropertiesForKeys: keys,
                                                      options: [.skipsPackageDescendants, .skipsHiddenFiles],
                                                      errorHandler: { _, _ in true }) else {
            return []
        }

        var results: [URL] = []
        let keySet = Set(keys)
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: keySet), values.isRegularFile == true else { continue }
            if ImageIOCapabilities.shared.isReadableURL(fileURL) {
                results.append(fileURL.standardizedFileURL)
            }
        }
        return results
    }
}

