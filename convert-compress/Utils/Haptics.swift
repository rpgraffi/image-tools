import AppKit

enum Haptics {
    static func generic() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }

    static func alignment() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    static func levelChange() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }
}

/// Helper class for tracking and providing haptic feedback when moving through discrete stops.
/// Use with @State to ensure proper persistence in SwiftUI views.
final class HapticStopTracker {
    private var lastStopIndex: Int?
    
    /// Triggers alignment haptic only if the current index has changed
    func handleStopChange(currentIndex: Int) {
        guard lastStopIndex != currentIndex else { return }
        Haptics.alignment()
        lastStopIndex = currentIndex
    }
    
    /// Resets the tracker state
    func reset() {
        lastStopIndex = nil
    }
}


