import SwiftUI
import AppKit

/// A view modifier that adds horizontal scroll gesture support for discrete steps.
struct ScrollGestureModifier: ViewModifier {
    let totalSteps: Int
    let sensitivity: Double
    let isEnabled: Bool
    let onScroll: (Int) -> Void
    
    @State private var scrollMonitor: Any?
    @State private var scrollAccumulator = 0.0
    
    func body(content: Content) -> some View {
        content
            .onHover { isHovering in
                scrollAccumulator = 0
                isHovering && isEnabled ? installScrollMonitor() : removeScrollMonitor()
            }
            .onDisappear { removeScrollMonitor() }
    }
    
    private func installScrollMonitor() {
        removeScrollMonitor()
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [self] event in
            guard isEnabled, abs(event.scrollingDeltaX) > 0.1 else { return nil }
            
            scrollAccumulator += event.scrollingDeltaX > 0 ? 1 : -1
            
            if abs(scrollAccumulator) >= sensitivity {
                let scrollSteps = Int((scrollAccumulator / sensitivity).rounded(.towardZero))
                scrollAccumulator = scrollAccumulator.truncatingRemainder(dividingBy: sensitivity)
                onScroll(scrollSteps)
            }
            return nil
        }
    }
    
    private func removeScrollMonitor() {
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
    }
}

extension View {
    /// Adds horizontal scroll gesture support for discrete steps.
    /// - Parameters:
    ///   - totalSteps: Total number of discrete steps (controls scroll speed normalization)
    ///   - sensitivity: Scroll ticks required per step (default: 3.0, lower = faster)
    ///   - isEnabled: Whether scroll is enabled (default: true)
    ///   - onScroll: Callback with step delta (+1 for right, -1 for left, etc.)
    func scrollGesture(
        totalSteps: Int,
        sensitivity: Double = 5.0,
        isEnabled: Bool = true,
        onScroll: @escaping (Int) -> Void
    ) -> some View {
        modifier(ScrollGestureModifier(
            totalSteps: totalSteps,
            sensitivity: sensitivity,
            isEnabled: isEnabled,
            onScroll: onScroll
        ))
    }
}

