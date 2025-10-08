import SwiftUI
import AppKit

/// Reusable percent slider pill with inline editing, drag interaction, scroll, and optional haptics.
struct PercentPill: View {
    let label: String
    @Binding var value01: Double
    let dragStep: Double
    let showsTenPercentHaptics: Bool
    let showsFullBoundaryHaptic: Bool

    @State private var isEditing = false
    @State private var percentString = "100"
    @State private var didHapticAtFull = false
    @State private var lastTenPercentTick: Int?

    var body: some View {
        GeometryReader { geo in
            let progress = value01.clamped(to: 0...1)
            
            ZStack(alignment: .leading) {
                PillBackground(
                    containerSize: geo.size,
                    cornerRadius: Theme.Metrics.pillCornerRadius(forHeight: geo.size.height),
                    progress: progress
                )
                
                HStack {
                    Text(label)
                        .font(Theme.Fonts.button)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if isEditing {
                        InlinePercentEditor(
                            isEditing: $isEditing,
                            text: $percentString,
                            onCommit: commitPercent,
                            onChangeFilter: { $0.filter(\.isNumber) }
                        )
                    } else {
                        Text("\(Int(progress * 100))%")
                            .font(Theme.Fonts.button)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .animation(Theme.Animations.fastSpring(), value: progress)
                    }
                }
                .padding(.horizontal, 12)
            }
            .contentShape(Rectangle())
            .onTapGesture { startEditing(progress: progress) }
            .scrollGesture(
                totalSteps: Int(1.0 / dragStep) + 1,
                isEnabled: !isEditing
            ) { steps in
                updateValue((value01 + Double(steps) * dragStep).clamped(to: 0...1))
            }
            .gesture(dragGesture(width: geo.size.width))
            .onAppear { percentString = "\(Int(progress * 100))" }
        }
    }
    
    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 2).onChanged { value in
            guard !isEditing else { return }
            let x = value.location.x.clamped(to: 0...width)
            let stepped = (x / width / dragStep).rounded() * dragStep
            updateValue(stepped.clamped(to: 0...1))
        }
    }
    
    private func startEditing(progress: Double) {
        guard !isEditing else { return }
        isEditing = true
        percentString = "\(Int(progress * 100))"
    }
    
    private func commitPercent() {
        let percent = (Int(percentString) ?? Int(value01 * 100)).clamped(to: 0...100)
        percentString = "\(percent)"
        updateValue(Double(percent) / 100)
    }
    
    private func updateValue(_ newValue: Double) {
        value01 = newValue
        triggerHaptics(for: newValue)
    }
    
    private func triggerHaptics(for progress: Double) {
        if showsFullBoundaryHaptic && progress >= 1.0 && !didHapticAtFull {
            Haptics.levelChange()
            didHapticAtFull = true
        } else if progress < 1.0 {
            didHapticAtFull = false
        }
        
        if showsTenPercentHaptics {
            let tick = Int((progress * 100).rounded())
            if tick % 10 == 0 && tick > 0 && tick < 100 && lastTenPercentTick != tick {
                Haptics.alignment()
                lastTenPercentTick = tick
            } else if tick % 10 != 0 {
                lastTenPercentTick = nil
            }
        }
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
} 
