import SwiftUI
import AppKit

// MARK: Change Detection
struct ImageChangeInfo {
    let resolutionChanged: Bool
    let fileSizeChanged: Bool
    let formatChanged: Bool
    let originalPixelSize: CGSize?
    let targetPixelSize: CGSize?
    let originalFileSize: Int?
    let estimatedOutputSize: Int?
    let originalFormat: ImageFormat?
    let targetFormat: ImageFormat?
    
    var hasChanges: Bool {
        resolutionChanged || fileSizeChanged || formatChanged
    }
    
    @MainActor
    init(asset: ImageAsset, vm: ImageToolsViewModel) {
        let preview = vm.previewInfo(for: asset)
        
        // Store original and target values
        self.originalPixelSize = asset.originalPixelSize
        self.targetPixelSize = preview.targetPixelSize
        self.originalFileSize = asset.originalFileSizeBytes
        self.estimatedOutputSize = vm.estimatedBytes[asset.id] ?? preview.estimatedOutputBytes
        self.originalFormat = ImageExporter.inferFormat(from: asset.originalURL)
        self.targetFormat = vm.selectedFormat ?? originalFormat
        
        // Detect changes
        self.resolutionChanged = Self.hasResolutionChange(
            from: originalPixelSize,
            to: targetPixelSize
        )
        self.fileSizeChanged = Self.hasFileSizeChange(
            from: originalFileSize,
            to: estimatedOutputSize
        )
        self.formatChanged = (originalFormat != targetFormat)
    }
    
    private static func hasResolutionChange(from original: CGSize?, to target: CGSize?) -> Bool {
        guard let orig = original, let targ = target else { return false }
        return Int(orig.width) != Int(targ.width) || Int(orig.height) != Int(targ.height)
    }
    
    private static func hasFileSizeChange(from original: Int?, to target: Int?) -> Bool {
        guard let orig = original, let targ = target else { return false }
        return orig != targ
    }
}

// MARK: Main View
struct ImageItem: View {
    let asset: ImageAsset
    @ObservedObject var vm: ImageToolsViewModel
    let heroNamespace: Namespace.ID
    
    @State private var isHovering: Bool = false
    @State private var keyEventMonitor: Any?
    
    private var fileName: String {
        asset.originalURL.lastPathComponent
    }
    
    var body: some View {
        let changeInfo = ImageChangeInfo(asset: asset, vm: vm)
        
        ZStack {
            thumbnailLayer
            fileNameOverlay
            hoverControlsOverlay
            infoOverlay(changeInfo: changeInfo)
        }
        .contentShape(Rectangle())
        .onHover(perform: handleHover)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onChange(of: vm.resizeMode) { vm.triggerEstimationForVisible([asset]) }
        .onChange(of: vm.resizeWidth) { vm.triggerEstimationForVisible([asset]) }
        .onChange(of: vm.resizeHeight) { vm.triggerEstimationForVisible([asset]) }
        .onChange(of: vm.selectedFormat) { vm.triggerEstimationForVisible([asset]) }
        .onChange(of: vm.compressionPercent) { vm.triggerEstimationForVisible([asset]) }
        .onChange(of: vm.removeMetadata) { vm.triggerEstimationForVisible([asset]) }
        .overlay { hoverBorder }
        .onDisappear { removeKeyMonitor() }
    }
}

// MARK: View Components
private extension ImageItem {
    @ViewBuilder
    var thumbnailLayer: some View {
        if let thumb = asset.thumbnail {
            ImageThumbnail(thumbnail: thumb)
                .matchedGeometryEffect(id: "hero-\(asset.id)", in: heroNamespace)
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.quaternary)
                .matchedGeometryEffect(id: "hero-\(asset.id)", in: heroNamespace)
        }
    }
    
    var fileNameOverlay: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            SingleLineOverlayBadge(text: fileName)
                .matchedGeometryEffect(id: "filename-\(asset.id)", in: heroNamespace)
                .padding(8)
        }
    }
    
    var hoverControlsOverlay: some View {
        ZStack(alignment: .topTrailing) {
            Color.clear
            HoverControls(asset: asset, vm: vm, isVisible: isHovering)
        }
    }
    
    func infoOverlay(changeInfo: ImageChangeInfo) -> some View {
        ZStack(alignment: .bottomLeading) {
            Color.clear
            InfoOverlay(changeInfo: changeInfo)
        }
    }
    
    var hoverBorder: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .inset(by: isHovering ? -2 : 0)
            .stroke(Color.secondary, lineWidth: 1.5)
            .opacity(isHovering ? 0.6 : 0)
            .animation(.easeInOut(duration: 0.15), value: isHovering)
    }
    
    func handleHover(_ hovering: Bool) {
        isHovering = hovering
        if hovering {
            installKeyMonitor()
        } else {
            removeKeyMonitor()
        }
    }
}

// MARK: Keyboard Handling
private extension ImageItem {
    func installKeyMonitor() {
        removeKeyMonitor()
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak vm, asset] event in
            // Spacebar
            if event.keyCode == 49 {
                vm?.presentComparison(for: asset)
                return nil
            }
            // X key
            if event.keyCode == 7 { 
                vm?.remove(asset)
                return nil
            }
            return event
        }
    }
    
    func removeKeyMonitor() {
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
    }
}
