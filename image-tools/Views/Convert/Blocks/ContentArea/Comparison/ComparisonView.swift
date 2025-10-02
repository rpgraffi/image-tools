import AppKit
import SwiftUI

struct ComparisonView: View {
    @EnvironmentObject var vm: ImageToolsViewModel
    let asset: ImageAsset
    let heroNamespace: Namespace.ID

    @State private var sliderPosition: CGFloat = 0.5
    @State private var isHandleHovering: Bool = false
    @State private var isDragging: Bool = false
    @State private var showUI: Bool = false
    @State private var keyEventMonitor: Any?

    private var preview: ComparisonPreviewState { vm.comparisonPreview }
    private var fileName: String { asset.originalURL.lastPathComponent }
    private var currentHandleSize: CGFloat {
        (isHandleHovering || isDragging) ? 46 : 34
    }

    var body: some View {
        GeometryReader { proxy in
            let containerWidth = max(proxy.size.width, 1)
            let imageFrame = calculateImageFrame(containerSize: proxy.size)

            comparisonLayers(imageWidth: imageFrame.width)
                .overlay(alignment: .center) {
                    if showUI {
                        splitHandle(height: imageFrame.height)
                            .offset(
                                x: (sliderPosition - 0.5) * imageFrame.width
                            )
                            .transition(
                                .opacity.combined(with: .scale(scale: 0.8))
                            )
                    }
                }
                .overlay(alignment: .top) {
                    if showUI {
                        topBar
                            .transition(
                                .move(edge: .top).combined(with: .opacity)
                            )
                    }
                }
                .overlay(alignment: .bottom) {
                    if showUI {
                        bottomLabels
                            .transition(
                                .move(edge: .bottom).combined(with: .opacity)
                            )
                    }
                }
                .gesture(
                    splitDrag(
                        imageFrame: imageFrame,
                        containerWidth: containerWidth
                    )
                )
                .onTapGesture { location in
                    handleTap(
                        location: location,
                        imageFrame: imageFrame,
                        containerWidth: containerWidth
                    )
                }
        }
        .onAppear {
            sliderPosition = 0.5
            vm.refreshComparisonPreview()
            withAnimation(Theme.Animations.fastSpring()) {
                showUI = true
            }
            installKeyMonitor()
        }
        .onChange(of: preview.processedImage) { _, newImage in
            if newImage != nil {
                vm.triggerEstimationForVisible([asset])
            }
        }
        .onDisappear {
            removeKeyMonitor()
        }
        .focusable()
        .focusEffectDisabled()
        .animation(Theme.Animations.fastSpring(), value: isHandleHovering)
    }

    private func comparisonLayers(imageWidth: CGFloat) -> some View {
        ZStack {
            heroImage(for: preview.originalImage ?? asset.thumbnail)

            // Processed image overlay (masked from left - shows on right side starting at sliderPosition)
            if let processedImage = preview.processedImage, showUI {
                processedOverlay(for: processedImage)
                    .mask(alignment: .trailing) {
                        GeometryReader { geo in
                            Rectangle()
                                .frame(width: (1.0 - sliderPosition) * imageWidth)
                                .frame(
                                    maxWidth: .infinity,
                                    maxHeight: .infinity,
                                    alignment: .trailing
                                )
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func heroImage(for image: NSImage?) -> some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Color.clear
            }
        }
        .matchedGeometryEffect(
            id: "hero-\(asset.id)",
            in: heroNamespace
        )
    }

    private func processedOverlay(for image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .scaledToFit()
            .matchedGeometryEffect(
                id: "hero-\(asset.id)",
                in: heroNamespace,
                isSource: false
            )
    }

    private func splitHandle(height: CGFloat) -> some View {
        let size = currentHandleSize
        return ZStack {
            Rectangle()
                .fill(.regularMaterial)
                .frame(width: 3, height: height)
            
            // Draggable handle
            Circle()
                .fill(.regularMaterial)
                .frame(width: size, height: size)
                .overlay(
                    Image(
                        systemName: "chevron.compact.left.chevron.compact.right"
                    )
                    .font(
                        .system(size: 14, weight: .semibold, design: .rounded)
                    )
                    .foregroundStyle(.primary)
                )
                .onHover { hovering in isHandleHovering = hovering }
        }
    }

    private func splitDrag(imageFrame: CGRect, containerWidth: CGFloat)
        -> some Gesture
    {
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
        HStack(alignment: .top) {
            SingleLineOverlayBadge(text: fileName)
                .matchedGeometryEffect(
                    id: "filename-\(asset.id)",
                    in: heroNamespace
                )
            Spacer()
            Button(action: { vm.dismissComparison() }) {
                ZStack {
                    Circle()
                        .fill(.regularMaterial)
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)
            .frame(width: 32, height: 32)
            .contentShape(Circle())
            .help(String(localized: "Close comparison"))
        }
        .padding(16)
    }

    private var bottomLabels: some View {
        return HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                imageInfoBadges(isOriginal: true)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                imageInfoBadges(isOriginal: false)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }

        }
        .padding(16)
    }

    // MARK: - Image Info Badges

    private func imageInfoBadges(isOriginal: Bool) -> some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isOriginal {
                SingleLineOverlayBadge(text: String(localized: "Original"), padding: 4)
            } else {
                SingleLineOverlayBadge(text: String(localized: "Preview"), padding: 4)
            }

            // Format badge
            if let format = isOriginal ? originalFormat : targetFormat {
                SingleLineOverlayBadge(text: format.displayName, padding: 4)
            }

            // Resolution badge
            if let size = isOriginal ? asset.originalPixelSize : targetPixelSize
            {
                SingleLineOverlayBadge(text: "\(Int(size.width))×\(Int(size.height))", padding: 4)
            }

            // File size badge
            if let bytes = isOriginal
                ? asset.originalFileSizeBytes : estimatedOutputBytes
            {
                SingleLineOverlayBadge(text: formatBytes(bytes), padding: 4)
            }
            
            // Savings badges (only for preview/processed side)
            if !isOriginal, let original = asset.originalFileSizeBytes, let estimated = estimatedOutputBytes, original != estimated {
                let difference = original - estimated
                let sign = difference > 0 ? "-" : "+"
                let absValue = abs(difference)
                let percentChange = Int(round(Double(absValue) / Double(original) * 100))
                
                SingleLineOverlayBadge(text: "\(sign)\(formatBytes(absValue))", padding: 4)
                SingleLineOverlayBadge(text: "\(sign)\(percentChange)%", padding: 4)
            }
        }
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
        vm.estimatedBytes[asset.id]
            ?? vm.previewInfo(for: asset).estimatedOutputBytes
    }

    // MARK: - Image Frame Calculation

    /// Calculates the actual frame of the fitted image within the container
    private func calculateImageFrame(containerSize: CGSize) -> CGRect {
        guard let image = preview.processedImage ?? preview.originalImage,
            image.size.width > 0, image.size.height > 0
        else {
            return CGRect(origin: .zero, size: containerSize)
        }

        let imageAspect = image.size.width / image.size.height
        let containerAspect = containerSize.width / containerSize.height

        let fittedSize =
            imageAspect > containerAspect
            ? CGSize(
                width: containerSize.width,
                height: containerSize.width / imageAspect
            )
            : CGSize(
                width: containerSize.height * imageAspect,
                height: containerSize.height
            )

        let origin = CGPoint(
            x: (containerSize.width - fittedSize.width) / 2,
            y: (containerSize.height - fittedSize.height) / 2
        )

        return CGRect(origin: origin, size: fittedSize)
    }

    /// Handles tap gestures on the comparison view
    private func handleTap(
        location: CGPoint,
        imageFrame: CGRect,
        containerWidth: CGFloat
    ) {
        let imageStartX = (containerWidth - imageFrame.width) / 2
        let relativeX = location.x - imageStartX
        let normalized = min(max(0, relativeX / imageFrame.width), 1)
        withAnimation(Theme.Animations.fastSpring()) { sliderPosition = normalized }
    }

    // MARK: - Keyboard Handling

    /// Installs a local event monitor to handle the Escape key
    /// This follows the same pattern used in FormatControl for keyboard shortcuts
    private func installKeyMonitor() {
        removeKeyMonitor()
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            [weak vm] event in
            if event.keyCode == 53 {  // Escape key
                vm?.dismissComparison()
                return nil  // Consume the event
            }
            return event  // Pass through other keys
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
    }
}
