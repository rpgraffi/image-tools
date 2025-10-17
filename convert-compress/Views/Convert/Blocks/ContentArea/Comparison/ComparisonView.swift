import AppKit
import SwiftUI

/// Comparison view with zoom, pan, and slider functionality
///
/// Gestures:
/// - Pinch: Zoom toward cursor position
/// - Two-finger scroll (trackpad): Pan in all directions
/// - Drag: Pan when zoomed
/// - Handle drag: Move comparison slider
/// - Mouse wheel + Option: Zoom (for mouse users)
/// - Keyboard: Space/Esc (close), arrows (navigate), C (toggle comparison)
struct ComparisonView: View {
    @EnvironmentObject private var vm: ImageToolsViewModel
    let asset: ImageAsset
    let heroNamespace: Namespace.ID
    
    @State private var sliderPosition: CGFloat = 0.5
    @State private var showUI: Bool = false
    @State private var previousPosition: CGFloat = 0.5
    @State private var keyEventMonitor: Any?
    @StateObject private var zoomPanState = ZoomPanState()
    @State private var lastDragLocation: CGPoint = .zero
    @State private var lastPointerLocation: CGPoint = .zero
    @State private var handleDragStartPosition: CGFloat? = nil
    
    private var preview: ComparisonPreviewState { vm.comparisonPreview }
    private var fileName: String { asset.originalURL.lastPathComponent }
    
    private var mainContent: some View {
        GeometryReader { proxy in
            let containerSize = proxy.size
            let imageFrame = calculateImageFrame(containerSize: containerSize)
            
            ZStack {
                // Main content with clipping
                ZStack {
                    comparisonContent(
                        containerSize: containerSize,
                        imageFrame: imageFrame
                    )
                }
                .background(.thickMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .matchedGeometryEffect(
                    id: "hero-\(asset.id)",
                    in: heroNamespace,
                )
                
                // Handle overlay
                if showUI {
                    ComparisonSplitHandle()
                    .position(
                        x: sliderPosition * containerSize.width,
                        y: containerSize.height / 2
                    )
                    .gesture(
                        handleDragGesture(containerSize: containerSize)
                    )
                    .transition(
                        .opacity.combined(with: .scale(scale: 0.8))
                    )
                    .allowsHitTesting(true)
                }
            }
            .overlay(alignment: .top) {
                if showUI {
                    ComparisonTop(
                        asset: asset,
                        heroNamespace: heroNamespace,
                        sliderPosition: $sliderPosition,
                        zoomPanState: zoomPanState
                    )
                    .transition(
                        .move(edge: .top).combined(with: .opacity)
                    )
                }
            }
            .overlay(alignment: .bottom) {
                if showUI {
                    ComparisonBottom(asset: asset)
                        .transition(
                            .move(edge: .bottom).combined(with: .opacity)
                        )
                }
            }
            .onChange(of: containerSize) { _, newSize in
                updateZoomPanContainer(size: newSize, imageFrame: imageFrame)
            }
            .onChange(of: imageFrame.size) { _, newSize in
                updateZoomPanContainer(size: containerSize, imageFrame: imageFrame)
            }
        }
    }
    
    var body: some View {
        mainContent
            .comparisonScrollHandler(zoomPanState: zoomPanState)
            .onAppear {
            sliderPosition = 0.5
            vm.refreshComparisonPreview()
            withAnimation(Theme.Animations.fastSpring()) {
                showUI = true
            }
            installKeyMonitor()
        }
        .onChange(of: asset.id) { _, _ in
            sliderPosition = 0.5
            zoomPanState.reset(animated: false)
            vm.refreshComparisonPreview()
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
    }
    
    private func comparisonContent(containerSize: CGSize, imageFrame: CGRect) -> some View {
        ZStack {
            // Container for zoomed/panned images
            ZStack {
                // Original image layer with zoom/pan
                originalImageLayer(imageFrame: imageFrame)
                
                // Processed image layer with zoom/pan and crop alignment
                if let processedImage = preview.processedImage, showUI {
                    processedImageLayer(
                        image: processedImage,
                        imageFrame: imageFrame
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    lastPointerLocation = location
                case .ended:
                    break
                }
            }
            .onTapGesture(count: 2) {
                zoomPanState.reset(animated: true)
            }
            .gesture(panGesture())
            .simultaneousGesture(magnificationGesture(containerSize: containerSize))
        }
    }
    
    private func originalImageLayer(imageFrame: CGRect) -> some View {
        GeometryReader { geo in
            Group {
                if let image = preview.originalImage ?? asset.thumbnail {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: imageFrame.width, height: imageFrame.height)
                        .scaleEffect(zoomPanState.scale, anchor: .center)
                        .offset(x: zoomPanState.offset.x, y: zoomPanState.offset.y)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                        .drawingGroup(opaque: false, colorMode: .nonLinear)
                } else {
                    Color.clear
                }
            }
        }
    }
    
    private func processedImageLayer(image: NSImage, imageFrame: CGRect) -> some View {
        let cropAlignment = calculateCropAlignment(
            imageFrame: imageFrame,
            cropRegion: preview.cropRegion
        )
        let isCropped = preview.cropRegion != nil
        
        return GeometryReader { geo in
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: cropAlignment.size.width, height: cropAlignment.size.height)
                .overlay {
                    if isCropped {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .strokeBorder(.secondary, lineWidth: 0.5)
                            .frame(width: cropAlignment.size.width, height: cropAlignment.size.height)
                    }
                }
                .offset(x: cropAlignment.offset.x, y: cropAlignment.offset.y)
                .scaleEffect(zoomPanState.scale, anchor: .center)
                .offset(x: zoomPanState.offset.x, y: zoomPanState.offset.y)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
                .drawingGroup(opaque: false, colorMode: .nonLinear)
                .mask(alignment: .trailing) {
                    Rectangle()
                        .frame(width: (1.0 - sliderPosition) * geo.size.width)
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity,
                            alignment: .trailing
                        )
                }
        }
    }
    
    // MARK: - Crop Alignment Calculation
    
    private func calculateCropAlignment(imageFrame: CGRect, cropRegion: CGRect?) -> (size: CGSize, offset: CGPoint) {
        guard let cropRegion = cropRegion,
              let originalSize = preview.originalSize,
              let _ = preview.processedSize else {
            // No crop - processed image fits same as original
            return (size: imageFrame.size, offset: .zero)
        }
        
        // Calculate scale factor to match original's display size
        // The processed image should appear at the size it would be if it were part of the original
        let originalDisplayWidth = imageFrame.width
        let originalDisplayHeight = imageFrame.height
        
        // Scale to make processed image match the dimensions it occupied in the original
        let cropWidthInOriginal = originalSize.width * cropRegion.width
        let cropHeightInOriginal = originalSize.height * cropRegion.height
        
        let scaleX = originalDisplayWidth / originalSize.width
        let scaleY = originalDisplayHeight / originalSize.height
        
        let processedDisplayWidth = cropWidthInOriginal * scaleX
        let processedDisplayHeight = cropHeightInOriginal * scaleY
        
        // Calculate offset to position at crop region
        let offsetX = (cropRegion.origin.x * originalDisplayWidth) + (processedDisplayWidth / 2) - (originalDisplayWidth / 2)
        let offsetY = (cropRegion.origin.y * originalDisplayHeight) + (processedDisplayHeight / 2) - (originalDisplayHeight / 2)
        
        return (
            size: CGSize(width: processedDisplayWidth, height: processedDisplayHeight),
            offset: CGPoint(x: offsetX, y: offsetY)
        )
    }
    
    // MARK: - Zoom/Pan Helpers
    
    private func updateZoomPanContainer(size: CGSize, imageFrame: CGRect) {
        zoomPanState.updateContainerAndImage(
            containerSize: size,
            imageSize: imageFrame.size
        )
    }
    
    // MARK: - Gesture Handlers
    
    private func panGesture() -> some Gesture {
        DragGesture()
            .onChanged { value in
                let delta = CGSize(
                    width: value.location.x - lastDragLocation.x,
                    height: value.location.y - lastDragLocation.y
                )
                if lastDragLocation != .zero {
                    zoomPanState.pan(by: delta)
                }
                lastDragLocation = value.location
            }
            .onEnded { _ in
                lastDragLocation = .zero
            }
    }
    
    private func handleDragGesture(containerSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // Calculate position relative to container, accounting for initial click offset
                let adjustedX = value.location.x - (handleDragStartPosition ?? 0)
                let normalized = min(max(0, adjustedX / containerSize.width), 1)
                
                // Trigger haptic when reaching a boundary
                if (normalized == 0 && previousPosition > 0) || (normalized == 1 && previousPosition < 1) {
                    Haptics.alignment()
                }
                
                previousPosition = normalized
                sliderPosition = normalized
            }
            .onEnded { _ in
                handleDragStartPosition = nil
            }
    }
    
    private func magnificationGesture(containerSize: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { [zoomPanState] value in
                // Use last tracked pointer location, or center (0,0) if not tracked
                let centerX = containerSize.width / 2
                let centerY = containerSize.height / 2
                let pointerInView = lastPointerLocation != .zero ? lastPointerLocation : CGPoint(x: centerX, y: centerY)
                
                // Convert to offset from center for the zoom calculation
                let offsetFromCenter = CGPoint(
                    x: pointerInView.x - centerX,
                    y: pointerInView.y - centerY
                )
                
                // Initialize magnification on first change
                if zoomPanState.lastMagnification == 1.0 && value != 1.0 {
                    zoomPanState.beginMagnification()
                }
                
                zoomPanState.updateMagnification(value, atOffsetFromCenter: offsetFromCenter)
            }
            .onEnded { [zoomPanState] _ in
                zoomPanState.endMagnification()
                
                // Haptic feedback when crossing 100% zoom
                if abs(zoomPanState.scale - zoomPanState.baseScale) < 0.05 {
                    Haptics.alignment()
                }
            }
    }
    
    // MARK: - Image Frame Calculation
    
    /// Calculates the frame of the fitted image within the container.
    /// Always uses original image to prevent view shrinking when cropping.
    private func calculateImageFrame(containerSize: CGSize) -> CGRect {
        guard let image = preview.originalImage ?? asset.thumbnail,
              image.size.width > 0, image.size.height > 0
        else {
            return CGRect(origin: .zero, size: containerSize)
        }
        
        let imageAspect = image.size.width / image.size.height
        let containerAspect = containerSize.width / containerSize.height
        
        let fittedSize = imageAspect > containerAspect
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
    
    // MARK: - Keyboard Handling
    
    private func installKeyMonitor() {
        removeKeyMonitor()
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            
            // Check if a text field is currently focused - if so, let arrow keys pass through
            if isTextFieldFocused() && (event.keyCode == 123 || event.keyCode == 124) {
                return event
            }
            
            switch event.keyCode {
            case 49, 53: // Spacebar or Escape
                vm.dismissComparison()
                return nil
            case 123: // Left arrow
                vm.navigateToPreviousImage()
                return nil
            case 124: // Right arrow
                vm.navigateToNextImage()
                return nil
            case 8: // C key - toggle comparison slider
                sliderPosition = sliderPosition < 0.5 ? 1.0 : 0.0
                return nil
            default:
                return event
            }
        }
    }
    
    private func removeKeyMonitor() {
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
    }
    
    private func isTextFieldFocused() -> Bool {
        guard let firstResponder = NSApp.keyWindow?.firstResponder else { return false }
        return firstResponder is NSText || firstResponder is NSTextField
    }
}
