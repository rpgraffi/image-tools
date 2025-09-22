import Foundation
import AppKit
import SwiftUI
import ImageIO
import StoreKit
import Combine

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
    @Published var sizeUnit: SizeUnitToggle = .percent { didSet { handleSizeUnitToggle(to: sizeUnit); persistSizeUnit() } }
    @Published var resizePercent: Double = 1.0
    @Published var resizeWidth: String = ""
    @Published var resizeHeight: String = ""
    
    @Published var storedPixelWidth: String? = nil
    @Published var storedPixelHeight: String? = nil

    @Published var selectedFormat: ImageFormat? = nil { didSet { persistSelectedFormat(); onSelectedFormatChanged() } }
    @Published var allowedSquareSizes: [Int]? = nil
    @Published var restrictionHint: String? = nil

    @Published var compressionPercent: Double = 0.8

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

    // Usage counts
    @Published private(set) var totalImageConversions: Int = 0
    @Published private(set) var totalPipelineApplications: Int = 0
    private var usageCancellable: AnyCancellable?

    // Paywall / purchase state
    @Published var isProUnlocked: Bool = false { didSet { persistPaywallState() } }
    @Published var isPaywallPresented: Bool = false
    // One-time gate so pressing Continue starts the just-requested apply without re-opening the paywall
    var shouldBypassPaywallOnce: Bool = false

    // MARK: - Init / Persistence
    init() {
        usageCancellable = UsageTracker.shared.$events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] events in
                guard let self = self else { return }
                self.totalImageConversions = events.filter { $0.kind == .imageConversion }.count
                self.totalPipelineApplications = events.filter { $0.kind == .pipelineApplied }.count
                self.persistUsageEvents(events)
            }
        loadPersistedState()
    }

    // MARK: - UI State Transitions
    func handleSizeUnitToggle(to newUnit: SizeUnitToggle) {
        switch newUnit {
        case .pixels:
            if let w = storedPixelWidth, let h = storedPixelHeight, (!w.isEmpty || !h.isEmpty) {
                resizeWidth = w
                resizeHeight = h
            } else {
                prefillPixelsIfPossible()
            }
        case .percent:
            storedPixelWidth = resizeWidth
            storedPixelHeight = resizeHeight
        }
    }

    // MARK: - Paywall actions
    func paywallContinueFree() {
        isPaywallPresented = false
        shouldBypassPaywallOnce = true
        applyPipelineAsync()
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