import SwiftUI
import AppKit

/// Reusable percent slider pill with inline editing, drag interaction, and optional haptics.
/// - value01: Binding in 0.0...1.0 range
/// - dragStep: step for drag updates (e.g. 0.05 for 5%)
/// - label: leading title text
struct PercentPill: View {
    let label: String
    @Binding var value01: Double
    let dragStep: Double
    let showsTenPercentHaptics: Bool
    let showsFullBoundaryHaptic: Bool

    @State private var isEditing: Bool = false
    @State private var percentString: String = "100"
    @State private var didHapticAtFull: Bool = false
    @State private var lastTenPercentTick: Int? = nil

    var body: some View {
        GeometryReader { geo in
            let container = geo.size
            let corner = Theme.Metrics.pillCornerRadius(forHeight: container.height)
            let clamped = min(max(value01, 0.0), 1.0)
            let progress = clamped
            ZStack(alignment: .leading) {
                PillBackground(containerSize: container, cornerRadius: corner, progress: progress)
                HStack{
                    Text(label)
                        .font(Theme.Fonts.button)
                        .foregroundColor(Color.secondary)
                        .fixedSize(horizontal: true, vertical: false)
                        
                    Spacer()
                    if isEditing {
                        InlinePercentEditor(
                            isEditing: $isEditing,
                            text: $percentString,
                            onCommit: { commitPercentFromString() },
                            onChangeFilter: { newValue in newValue.filter { $0.isNumber } }
                        )
                    } else {
                        Text("\(Int(clamped * 100))%")
                            .font(Theme.Fonts.button)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .monospacedDigit()
                            .fixedSize(horizontal: true, vertical: false)
                            .multilineTextAlignment(.trailing)
                            .contentTransition(.numericText())
                            .animation(Theme.Animations.fastSpring(), value: clamped)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                isEditing = true
                                percentString = String(Int(clamped * 100))
                            }
                    }
                }
                .padding(.horizontal, 12)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if !isEditing {
                    isEditing = true
                    percentString = String(Int(clamped * 100))
                }
            }
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        if isEditing { return }
                        let width = max(container.width, 1)
                        let x = min(max(0, value.location.x), width)
                        let raw = Double(x / width)
                        let stepped = max(0.0, min(1.0, (raw / dragStep).rounded() * dragStep))
                        value01 = stepped
                        handleHaptics(progress: stepped)
                    }
            )
            .onAppear { percentString = String(Int(clamped * 100)) }
        }
    }

    private func commitPercentFromString() {
        let parsed = Int(percentString) ?? Int(value01 * 100)
        let clampedPercent = max(0, min(100, parsed))
        percentString = String(clampedPercent)
        value01 = Double(clampedPercent) / 100.0
    }

    private func handleHaptics(progress: Double) {
        // Full boundary haptic (100%)
        if showsFullBoundaryHaptic {
            if progress >= 1.0 && !didHapticAtFull {
                Haptics.levelChange()
                didHapticAtFull = true
            } else if progress < 1.0 && didHapticAtFull {
                didHapticAtFull = false
            }
        }
        // Ten-percent tick haptics (10%, 20%, ... 90%)
        if showsTenPercentHaptics {
            let currentTick = Int((progress * 100).rounded())
            if currentTick % 10 == 0 && currentTick > 0 && currentTick < 100 {
                if lastTenPercentTick != currentTick {
                    Haptics.alignment()
                    lastTenPercentTick = currentTick
                }
            } else if lastTenPercentTick != nil {
                lastTenPercentTick = nil
            }
        }
    }
} 
