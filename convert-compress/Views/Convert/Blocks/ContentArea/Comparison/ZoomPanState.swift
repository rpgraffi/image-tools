import SwiftUI
import AppKit

/// Manages zoom and pan state for the comparison view
@MainActor
final class ZoomPanState: ObservableObject {
    // MARK: - Published Properties
    
    @Published var scale: CGFloat = 1.0
    @Published var offset: CGPoint = .zero
    @Published var containerSize: CGSize = .zero
    @Published var imageSize: CGSize = .zero
    
    // MARK: - Internal Properties
    
    private(set) var baseScale: CGFloat = 1.0
    var lastMagnification: CGFloat = 1.0
    
    // MARK: - Constants
    
    let minScaleMultiplier: CGFloat = 0.5  // Can zoom out to 50% of fit
    let maxScale: CGFloat = 20.0
    
    var zoomPercent: Int {
        Int(round(scale * 100))
    }
    
    var minScale: CGFloat {
        max(0.1, baseScale * minScaleMultiplier)
    }
    
    var isZoomed: Bool {
        scale > baseScale * 1.01
    }
    
    // MARK: - Initialization
    
    func updateContainerAndImage(containerSize: CGSize, imageSize: CGSize) {
        self.containerSize = containerSize
        self.imageSize = imageSize
        calculateBaseScale()
    }
    
    private func calculateBaseScale() {
        guard containerSize.width > 0, containerSize.height > 0,
              imageSize.width > 0, imageSize.height > 0 else {
            baseScale = 1.0
            return
        }
        
        let containerAspect = containerSize.width / containerSize.height
        let imageAspect = imageSize.width / imageSize.height
        
        // Calculate scale to fit image in container
        baseScale = imageAspect > containerAspect
            ? containerSize.width / imageSize.width
            : containerSize.height / imageSize.height
    }
    
    // MARK: - Zoom Operations
    
    /// Zoom by a delta amount, centered on a point (offset from center)
    func zoom(by delta: CGFloat, atOffsetFromCenter pointFromCenter: CGPoint) {
        let oldScale = scale
        let newScale = (scale * delta).clamped(to: minScale...maxScale)
        
        guard newScale != oldScale else { return }
        
        // Adjust offset to zoom toward the point
        let scaleDelta = newScale / oldScale
        offset.x = (offset.x - pointFromCenter.x) * scaleDelta + pointFromCenter.x
        offset.y = (offset.y - pointFromCenter.y) * scaleDelta + pointFromCenter.y
        
        scale = newScale
        constrainOffset()
    }
    
    /// Zoom by a delta amount, centered on a point in the container coordinate space
    func zoom(by delta: CGFloat, at point: CGPoint) {
        // Calculate point relative to center
        let centerX = containerSize.width / 2
        let centerY = containerSize.height / 2
        let pointFromCenter = CGPoint(x: point.x - centerX, y: point.y - centerY)
        
        zoom(by: delta, atOffsetFromCenter: pointFromCenter)
    }
    
    /// Zoom to a specific scale level, centered on container
    func zoomTo(_ targetScale: CGFloat, animated: Bool = true) {
        let newScale = targetScale.clamped(to: minScale...maxScale)
        
        if animated {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                scale = newScale
                offset = .zero
            }
        } else {
            scale = newScale
            offset = .zero
        }
    }
    
    /// Start magnification gesture
    func beginMagnification() {
        lastMagnification = 1.0
    }
    
    /// Update magnification gesture (at offset from center)
    func updateMagnification(_ value: CGFloat, atOffsetFromCenter offsetFromCenter: CGPoint) {
        let delta = value / lastMagnification
        lastMagnification = value
        zoom(by: delta, atOffsetFromCenter: offsetFromCenter)
    }
    
    /// End magnification gesture
    func endMagnification() {
        lastMagnification = 1.0
        constrainOffset()
    }
    
    // MARK: - Pan Operations
    
    func pan(by delta: CGSize) {
        offset.x += delta.width
        offset.y += delta.height
        constrainOffset()
    }
    
    func constrainOffset() {
        guard containerSize.width > 0, containerSize.height > 0 else { return }
        
        // Calculate the size of the scaled image
        let scaledWidth = imageSize.width * scale
        let scaledHeight = imageSize.height * scale
        
        // Allow panning but keep at least 20% of image visible
        let minVisibleRatio: CGFloat = 0.2
        let maxOffsetX = (scaledWidth * (1 - minVisibleRatio / 2)) / 2
        let maxOffsetY = (scaledHeight * (1 - minVisibleRatio / 2)) / 2
        
        offset.x = offset.x.clamped(to: -maxOffsetX...maxOffsetX)
        offset.y = offset.y.clamped(to: -maxOffsetY...maxOffsetY)
    }
    
    // MARK: - Reset Operations
    
    func reset(animated: Bool = true) {
        if animated {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                scale = baseScale
                offset = .zero
            }
        } else {
            scale = baseScale
            offset = .zero
        }
    }
    
    func fitToContainer(animated: Bool = false) {
        calculateBaseScale()
        if animated {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                scale = baseScale
                offset = .zero
            }
        } else {
            scale = baseScale
            offset = .zero
        }
    }
}

