import Foundation

extension ImageToolsViewModel {
    private enum PersistenceKeys {
        static let recentFormats = "image_tools.recent_formats.v1"
        static let selectedFormat = "image_tools.selected_format.v1"
        static let exportDirectory = "image_tools.export_directory.v1"
        static let sizeUnit = "image_tools.size_unit.v1"
        static let usageEvents = "image_tools.usage_events.v1"
        static let isProUnlocked = "image_tools.is_pro_unlocked.v1"
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

        if let unitRaw = defaults.string(forKey: PersistenceKeys.sizeUnit) {
            switch unitRaw {
            case "pixels":
                sizeUnit = .pixels
            case "percent": fallthrough
            default:
                sizeUnit = .percent
            }
        }

        // Initialize restrictions after selectedFormat restoration
        updateRestrictions()

        // Load usage tracking events
        loadUsageEvents()

        // Load paywall state
        isProUnlocked = defaults.bool(forKey: PersistenceKeys.isProUnlocked)
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

    func persistSizeUnit() {
        let defaults = UserDefaults.standard
        let value = (sizeUnit == .pixels) ? "pixels" : "percent"
        defaults.set(value, forKey: PersistenceKeys.sizeUnit)
    }

    // MARK: - Usage tracking persistence
    func loadUsageEvents() {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: PersistenceKeys.usageEvents) else { return }
        if let decoded = try? JSONDecoder().decode([UsageEvent].self, from: data) {
            UsageTracker.shared.replaceAll(decoded)
        }
    }

    func persistUsageEvents(_ events: [UsageEvent]) {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(events) {
            defaults.set(data, forKey: PersistenceKeys.usageEvents)
        }
    }

    // MARK: - Paywall state
    func persistPaywallState() {
        let defaults = UserDefaults.standard
        defaults.set(isProUnlocked, forKey: PersistenceKeys.isProUnlocked)
    }
}


