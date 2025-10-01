import SwiftUI
import AppKit

struct ComparisonView: View {
    @EnvironmentObject var vm: ImageToolsViewModel
    let asset: ImageAsset
    let heroNamespace: Namespace.ID

    @State private var sliderPosition: CGFloat = 0.5
    @State private var isHandleHovering: Bool = false
    @State private var isDragging: Bool = false
    @State private var showUI: Bool = false
    @State private var hasShownProcessedImage: Bool = false
    @State private var keyEventMonitor: Any?
    @Environment(\.colorScheme) private var colorScheme

    private var preview: ComparisonPreviewState { vm.comparisonPreview }
    private var fileName: String { asset.originalURL.lastPathComponent }
    private var currentHandleSize: CGFloat { (isHandleHovering || isDragging) ? 46 : 34 }

    var body: some View {
        GeometryReader { proxy in
            let containerWidth = max(proxy.size.width, 1)
            let containerHeight = proxy.size.height
            let imageFrame = calculateImageFrame(containerSize: proxy.size)

            comparisonLayers(imageWidth: imageFrame.width)
            .overlay(alignment: .center) {
                if showUI {
                    splitHandle(height: imageFrame.height)
                        .offset(x: (sliderPosition - 0.5) * imageFrame.width)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))    
                }
            }
            .overlay(alignment: .top) {
                if showUI {
                    topBar
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .overlay(alignment: .bottom) {
                if showUI {
                    bottomLabels
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .gesture(splitDrag(imageFrame: imageFrame, containerWidth: containerWidth))
            .onTapGesture { location in
                handleTap(location: location, imageFrame: imageFrame, containerWidth: containerWidth)
            }
        }
        .onAppear { 
            sliderPosition = 0.5
            
            // Delay loading until after hero animation starts
            Task {
                // Wait for hero animation to begin
                try? await Task.sleep(for: .milliseconds(100))
                vm.refreshComparisonPreview()
            }
            
            // Show UI controls after hero animation
            withAnimation(.easeOut(duration: 0.25).delay(0.35)) {
                showUI = true
            }
            
            installKeyMonitor()
        }
        .onChange(of: preview.processedImage) { _, newImage in
            if newImage != nil {
                // Only animate on first load, not on parameter updates
                if !hasShownProcessedImage {
                    withAnimation(.easeOut(duration: 0.3).delay(0.2)) {
                        hasShownProcessedImage = true
                    }
                } else {
                    hasShownProcessedImage = true
                }
                // Trigger estimation update for the file size badges
                vm.triggerEstimationForVisible([asset])
            }
        }
        .onDisappear {
            removeKeyMonitor()
        }
        .focusable()
        .focusEffectDisabled()
        .animation(.easeInOut(duration: 0.15), value: isHandleHovering)
    }

    private func comparisonLayers(imageWidth: CGFloat) -> some View {
        ZStack {
            
            // Preview/Processed image (base layer - shows on right side)
            if let processed = preview.processedImage, hasShownProcessedImage {
                Image(nsImage: processed)
                    .resizable()
                    .scaledToFit()
                    .transition(.opacity)
            } else if let originalImage = preview.originalImage {
                // Show original as placeholder while processing
                Image(nsImage: originalImage)
                    .resizable()
                    .scaledToFit()
                    .matchedGeometryEffect(id: "hero-\(asset.id)", in: heroNamespace)
            } else {
                Color.secondary.opacity(0.18)
                    .matchedGeometryEffect(id: "hero-\(asset.id)", in: heroNamespace)
            }
            
            // Original image overlay (masked from left - shows on left side)
            if let originalImage = preview.originalImage, showUI, preview.processedImage != nil, hasShownProcessedImage {
                Image(nsImage: originalImage)
                    .resizable()
                    .scaledToFit()
                    .matchedGeometryEffect(id: "hero-\(asset.id)", in: heroNamespace)
                    .mask(alignment: .leading) {
                        GeometryReader { geo in
                            Rectangle()
                                .frame(width: sliderPosition * imageWidth)
                                .frame(maxHeight: .infinity, alignment: .leading)
                        }
                    }
                    .animation(.linear(duration: isDragging ? 0 : 0.18), value: sliderPosition)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func splitHandle(height: CGFloat) -> some View {
        let size = currentHandleSize
        return ZStack {
            RoundedRectangle(cornerRadius: 0.75)
                .fill(Color.primary)
                .frame(width: 4, height: height)
                .shadow(color: Color.black.opacity(0.15), radius: 2, y: 1)

            Circle()
                .fill(Color.accentColor)
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "chevron.compact.left.chevron.compact.right")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 6, y: 3)
                .onHover { hovering in isHandleHovering = hovering }
        }
    }

    private func splitDrag(imageFrame: CGRect, containerWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isDragging = true
                // Calculate position relative to the image bounds
                let imageStartX = (containerWidth - imageFrame.width) / 2
                let relativeX = value.location.x - imageStartX
                let normalized = min(max(0, relativeX / imageFrame.width), 1)
                sliderPosition = normalized
            }
            .onEnded { _ in
                isDragging = false
            }
    }

    private var topBar: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(fileName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                if let size = asset.originalPixelSize {
                    Text("Original: \(Int(size.width)) × \(Int(size.height))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            CircleIconButton(action: { vm.dismissComparison() }) {
                Image(systemName: "xmark")
            }
            .help(String(localized: "Close comparison"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 12, y: 4)
        .padding(16)
    }

    private var bottomLabels: some View {
        // Force badge updates when processed image or estimated bytes change
        let updateTrigger = "\(preview.processedImage != nil)-\(preview.isLoading)-\(vm.estimatedBytes[asset.id] ?? 0)"
        
        return HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                comparisonChip(title: String(localized: "Original"))
                if hasShownProcessedImage, !preview.isLoading {
                    imageInfoBadges(isOriginal: true)
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                        .id("original-\(updateTrigger)")
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                comparisonChip(title: String(localized: "Preview"))
                if hasShownProcessedImage, !preview.isLoading {
                    imageInfoBadges(isOriginal: false)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                        .id("processed-\(updateTrigger)")
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func comparisonChip(title: String) -> some View {
        Text(title)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
    }
    
    // MARK: - Image Info Badges
    
    private func imageInfoBadges(isOriginal: Bool) -> some View {
        HStack(alignment: .bottom, spacing: 6) {
            // Format badge
            if let format = isOriginal ? originalFormat : targetFormat {
                infoBadge(text: format.displayName)
            }
            
            // Resolution badge
            if let size = isOriginal ? asset.originalPixelSize : targetPixelSize {
                infoBadge(text: "\(Int(size.width))×\(Int(size.height))")
            }
            
            // File size badge
            if let bytes = isOriginal ? asset.originalFileSizeBytes : estimatedOutputBytes {
                infoBadge(text: formatBytes(bytes))
            }
        }
    }
    
    private func infoBadge(text: String) -> some View {
        Text(text)
            .font(Theme.Fonts.captionMono)
            .monospaced(true)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Material.ultraThin)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
                    )
            )
    }
    
    private var originalFormat: ImageFormat? {
        ImageExporter.inferFormat(from: asset.originalURL)
    }
    
    private var targetFormat: ImageFormat? {
        vm.selectedFormat ?? originalFormat
    }
    
    private var targetPixelSize: CGSize? {
        vm.previewInfo(for: asset).targetPixelSize
    }
    
    private var estimatedOutputBytes: Int? {
        vm.estimatedBytes[asset.id] ?? vm.previewInfo(for: asset).estimatedOutputBytes
    }
    
    // MARK: - Image Frame Calculation
    
    /// Calculates the actual frame of the fitted image within the container
    private func calculateImageFrame(containerSize: CGSize) -> CGRect {
        guard let image = preview.processedImage ?? preview.originalImage,
              image.size.width > 0, image.size.height > 0 else {
            return CGRect(origin: .zero, size: containerSize)
        }
        
        let imageAspect = image.size.width / image.size.height
        let containerAspect = containerSize.width / containerSize.height
        
        let fittedSize = imageAspect > containerAspect
            ? CGSize(width: containerSize.width, height: containerSize.width / imageAspect)
            : CGSize(width: containerSize.height * imageAspect, height: containerSize.height)
        
        let origin = CGPoint(
            x: (containerSize.width - fittedSize.width) / 2,
            y: (containerSize.height - fittedSize.height) / 2
        )
        
        return CGRect(origin: origin, size: fittedSize)
    }
    
    /// Handles tap gestures on the comparison view
    private func handleTap(location: CGPoint, imageFrame: CGRect, containerWidth: CGFloat) {
        let imageStartX = (containerWidth - imageFrame.width) / 2
        let relativeX = location.x - imageStartX
        let normalized = min(max(0, relativeX / imageFrame.width), 1)
        withAnimation(.easeOut(duration: 0.18)) { sliderPosition = normalized }
    }
    
    // MARK: - Keyboard Handling
    
    /// Installs a local event monitor to handle the Escape key
    /// This follows the same pattern used in FormatControl for keyboard shortcuts
    private func installKeyMonitor() {
        removeKeyMonitor()
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak vm] event in
            if event.keyCode == 53 { // Escape key
                vm?.dismissComparison()
                return nil // Consume the event
            }
            return event // Pass through other keys
        }
    }
    
    private func removeKeyMonitor() {
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
    }
}




