import Foundation
import AppKit
import SwiftUI
import ImageIO

final class ImageToolsViewModel: ObservableObject {
    @Published var images: [ImageAsset] = []

    @Published var overwriteOriginals: Bool = false
    // Persist selected export directory between sessions
    @Published var exportDirectory: URL? = nil { didSet { persistExportDirectory() } }
    // Last detected source directory from most recent import
    @Published var sourceDirectory: URL? = nil
    var isExportingToSource: Bool {
        guard let source = sourceDirectory?.standardizedFileURL else { return false }
        let export = exportDirectory?.standardizedFileURL
        return export == nil || export == source
    }

    // UI toggles/state
    @Published var sizeUnit: SizeUnitToggle = .percent
    @Published var resizePercent: Double = 1.0
    @Published var resizeWidth: String = ""
    @Published var resizeHeight: String = ""

    @Published var selectedFormat: ImageFormat? = nil { didSet { persistSelectedFormat(); onSelectedFormatChanged() } }
    @Published var allowedSquareSizes: [Int]? = nil
    @Published var restrictionHint: String? = nil

    @Published var compressionMode: CompressionModeToggle = .percent
    @Published var compressionPercent: Double = 0.8
    @Published var compressionTargetKB: String = ""

    @Published var rotation: ImageRotation = .r0
    @Published var flipH: Bool = false
    @Published var flipV: Bool = false
    @Published var removeBackground: Bool = false
    @Published var removeMetadata: Bool = false

    // Recently used formats for prioritization
    @Published var recentFormats: [ImageFormat] = [] { didSet { persistRecentFormats() } }

    // Estimated sizes per image (bytes); UI displays "--- KB" when nil/absent
    @Published var estimatedBytes: [UUID: Int] = [:]
    var estimationTask: Task<Void, Never>? = nil

    // Export progress state
    @Published var isExporting: Bool = false
    @Published var exportCompleted: Int = 0
    @Published var exportTotal: Int = 0
    var exportFraction: Double {
        guard isExporting, exportTotal > 0 else { return 0 }
        return Double(exportCompleted) / Double(exportTotal)
    }

    // MARK: - Init / Persistence
    init() {
        loadPersistedState()
    }

    // MARK: - Clear all images
    func clearAll() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85, blendDuration: 0.3)) {
            images.removeAll()
        }
        // Reset automatic source-based destination only if no explicit export directory is set
        if exportDirectory == nil {
            sourceDirectory = nil
        }
    }
} 