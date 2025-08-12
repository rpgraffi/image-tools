import Foundation

extension ImageToolsViewModel {
    private enum PersistenceKeys {
        static let recentFormats = "image_tools.recent_formats.v1"
        static let selectedFormat = "image_tools.selected_format.v1"
        static let exportDirectory = "image_tools.export_directory.v1"
    }

    func loadPersistedState() {
        let defaults = UserDefaults.standard

        if let raw = defaults.array(forKey: PersistenceKeys.recentFormats) as? [String] {
            let mapped = raw.compactMap { ImageIOCapabilities.shared.format(forIdentifier: $0) }
            if !mapped.isEmpty { recentFormats = Array(mapped.prefix(3)) }
        }

        if let selRaw = defaults.string(forKey: PersistenceKeys.selectedFormat),
           let fmt = ImageIOCapabilities.shared.format(forIdentifier: selRaw) {
            let caps = ImageIOCapabilities.shared
            if caps.supportsWriting(utType: fmt.utType) { selectedFormat = fmt }
        }

        if let exportPath = defaults.string(forKey: PersistenceKeys.exportDirectory) {
            exportDirectory = URL(fileURLWithPath: exportPath)
        }

        // Initialize restrictions after selectedFormat restoration
        updateRestrictions()
    }

    func persistRecentFormats() {
        let defaults = UserDefaults.standard
        defaults.set(recentFormats.map { $0.id }, forKey: PersistenceKeys.recentFormats)
    }

    func persistSelectedFormat() {
        let defaults = UserDefaults.standard
        defaults.set(selectedFormat?.id, forKey: PersistenceKeys.selectedFormat)
    }

    func persistExportDirectory() {
        let defaults = UserDefaults.standard
        if let dir = exportDirectory {
            defaults.set(dir.path, forKey: PersistenceKeys.exportDirectory)
        } else {
            defaults.removeObject(forKey: PersistenceKeys.exportDirectory)
        }
    }
}


