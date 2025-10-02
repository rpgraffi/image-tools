import Foundation
import AppKit
import SwiftUI
import ImageIO
import StoreKit
import Combine

@MainActor
final class ImageToolsViewModel: ObservableObject {
    
    // MARK: - Images & Comparison State
    
    @Published var images: [ImageAsset] = []
    @Published var comparisonSelection: ComparisonSelection? = nil
    @Published var comparisonPreview: ComparisonPreviewState = .empty
    var comparisonPreviewTask: Task<Void, Never>? = nil
    var liveRenderDebounceWorkItem: DispatchWorkItem?
    
    // MARK: - Export Configuration
    
    @Published var overwriteOriginals: Bool = false
    @Published var exportDirectory: URL? = nil
    @Published var sourceDirectory: URL? = nil
    
    var isExportingToSource: Bool {
        guard let source = sourceDirectory?.standardizedFileURL else { return false }
        let export = exportDirectory?.standardizedFileURL
        return export == nil || export == source
    }
    
    // MARK: - Resize Settings
    
    @Published var sizeUnit: SizeUnitToggle = .pixels
    @Published var resizePercent: Double = 1.0
    @Published var resizeWidth: String = ""
    @Published var resizeHeight: String = ""
    @Published var storedPixelWidth: String? = nil
    @Published var storedPixelHeight: String? = nil
    
    // MARK: - Format Settings
    
    @Published var selectedFormat: ImageFormat? = nil
    @Published var allowedSquareSizes: [Int]? = nil
    @Published var restrictionHint: String? = nil
    @Published var recentFormats: [ImageFormat] = []
    
    // MARK: - Transform Settings
    
    @Published var compressionPercent: Double = 0.8
    @Published var flipV: Bool = false
    @Published var removeBackground: Bool = false
    @Published var removeMetadata: Bool = false
    
    // MARK: - Estimation State
    
    @Published var estimatedBytes: [UUID: Int] = [:]
    var estimationTask: Task<Void, Never>? = nil
    
    // MARK: - Export Progress
    
    @Published var isExporting: Bool = false
    @Published var exportCompleted: Int = 0
    @Published var exportTotal: Int = 0
    
    var exportFraction: Double {
        guard isExporting, exportTotal > 0 else { return 0 }
        return Double(exportCompleted) / Double(exportTotal)
    }
    
    // MARK: - Ingestion Progress
    
    @Published var isIngesting: Bool = false
    @Published var ingestCompleted: Int = 0
    @Published var ingestTotal: Int = 0
    
    var ingestFraction: Double {
        guard isIngesting, ingestTotal > 0 else { return 0 }
        return Double(ingestCompleted) / Double(ingestTotal)
    }
    
    var ingestCounterText: String? {
        guard isIngesting, ingestTotal > 0 else { return nil }
        let displayed = min(ingestCompleted + (ingestCompleted < ingestTotal ? 1 : 0), ingestTotal)
        return String("\(displayed)/\(ingestTotal)")
    }
    
    // MARK: - Usage Tracking
    
    @Published private(set) var totalImageConversions: Int = 0
    @Published private(set) var totalPipelineApplications: Int = 0
    private var usageCancellable: AnyCancellable?
    
    // MARK: - Paywall State
    
    @Published var isProUnlocked: Bool = false
    @Published var isPaywallPresented: Bool = false
    var shouldBypassPaywallOnce: Bool = false
    
    // MARK: - Subscriptions
    
    var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        setupComparisonObservation()
        setupUsageTracking()
        loadPersistedState()
        setupPersistenceObservation()
    }
    
    private func setupUsageTracking() {
        usageCancellable = UsageTracker.shared.$events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] events in
                guard let self = self else { return }
                self.totalImageConversions = events.filter { $0.kind == .imageConversion }.count
                self.totalPipelineApplications = events.filter { $0.kind == .pipelineApplied }.count
                self.persistUsageEvents(events)
            }
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
        comparisonSelection = nil
    }
} 