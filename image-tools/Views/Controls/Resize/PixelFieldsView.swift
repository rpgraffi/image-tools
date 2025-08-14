import SwiftUI
import AppKit

/// Single numeric pixel field with inline dimension toggle ("long" / "high").
/// The field edits either `widthText` or `heightText` based on the active toggle.
struct PixelFieldsView: View {
    @Binding var widthText: String
    @Binding var heightText: String
    let baseSize: CGSize?
    let containerSize: CGSize
    let squareLocked: Bool
    
    private enum ActiveDimension { case width, height }
    
    @State private var activeDimension: ActiveDimension = .width
    @FocusState private var fieldFocused: Bool
    @State private var lastStopIndex: Int? = nil
    @State private var isDragging: Bool = false
    @State private var isEditingField: Bool = false
    @State private var inlineText: String = ""
    
    private var activeText: String {
        activeDimension == .width ? widthText : heightText
    }
    
    private func assignActive(_ newValue: String) {
        if activeDimension == .width {
            widthText = newValue
            heightText = ""
        } else {
            heightText = newValue
            widthText = ""
        }
    }
    
    var body: some View {
        let corner = Theme.Metrics.pillCornerRadius(forHeight: containerSize.height)
        let stops = allowedStopsForActiveDimension()
        let progress = valueToProgress(stops: stops)
        
        return HStack(spacing: 0) {
            ZStack {
                PillBackground(
                    containerSize: containerSize,
                    cornerRadius: corner,
                    progress: progress,
                    // Always show full fill; do not fade near end for this control
                    fadeStart: 2.0
                )
                contentRow(containerHeight: containerSize.height)
                .allowsHitTesting(!isDragging)
                .padding(.horizontal, 0)
            }
            .font(Theme.Fonts.button)
            .frame(width: containerSize.width, height: containerSize.height)
            .contentShape(Rectangle())
            .onTapGesture {
                if !isDragging {
                    beginEditing()
                }
            }
            .highPriorityGesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        isDragging = true
                        // End editing so drag doesn't fight the text field
                        if fieldFocused {
                            NSApp.keyWindow?.endEditing(for: nil)
                            fieldFocused = false
                        }
                        guard !stops.isEmpty else { return }
                        let width = max(containerSize.width, 1)
                        let x = min(max(0, value.location.x), width)
                        let p = Double(x / width)
                        let idx = Int((p * Double(max(stops.count - 1, 1))).rounded())
                        let clampedIdx = min(max(0, idx), max(stops.count - 1, 0))
                        let side = stops[clampedIdx]
                        assignActive(String(side))
                        handleStopHaptics(currentIndex: clampedIdx)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .animation(Theme.Animations.pillFill(), value: progress)
        }
        .onAppear {
            initializeActiveDimension()
            refocusAndSelectAll()
        }
        .onChange(of: activeDimension) {
            refocusAndSelectAll()
            lastStopIndex = nil
            isEditingField = false
        }
    }
    
    private func initializeActiveDimension() {
        if !heightText.isEmpty, (widthText.isEmpty || (Int(widthText) == nil && Int(heightText) != nil)) {
            activeDimension = .height
            // Enforce single-source-of-truth: clear the inactive counterpart.
            widthText = ""
        } else {
            activeDimension = .width
            // Enforce single-source-of-truth: clear the inactive counterpart.
            heightText = ""
        }
    }
    
    private func refocusAndSelectAll() {
        // Attempt to select all text in the current first responder text field
        // Avoid creating a field editor explicitly; only act when a session exists.
        DispatchQueue.main.async {
            fieldFocused = true
            selectAllInFirstResponder()
        }
    }
    
    private func selectAllInFirstResponder() {
        if let window = NSApp.keyWindow,
           let textView = window.firstResponder as? NSTextView {
            textView.selectAll(nil)
        }
    }
    
    private func beginEditing() {
        isEditingField = true
        inlineText = activeText
        DispatchQueue.main.async {
            fieldFocused = true
            selectAllInFirstResponder()
        }
    }

    // MARK: - Stops and drag mapping
    private func hardcodedStops() -> [Int] {
        return [32, 64, 128, 256, 512, 1024, 1080, 1500, 1920, 2048, 2160, 3840]
    }

    private func allowedStopsForActiveDimension() -> [Int] {
        let all = hardcodedStops()
        guard let base = baseSize else { return all }
        let cap = activeDimension == .width ? Int(base.width) : Int(base.height)
        if cap <= 0 { return all }
        return all.filter { $0 <= cap }
    }

    private func valueToProgress(stops: [Int]) -> Double {
        guard !stops.isEmpty else { return 0 }
        let currentValue: Int = Int(activeText) ?? 0
        if let idx = stops.firstIndex(of: currentValue), stops.count > 1 {
            return Double(idx) / Double(stops.count - 1)
        }
        // If current value isn't exactly a stop, use nearest for progress display
        if stops.count > 1 {
            let nearestIdx = stops.enumerated().min(by: { abs($0.element - currentValue) < abs($1.element - currentValue) })?.offset ?? 0
            return Double(nearestIdx) / Double(stops.count - 1)
        } else {
            return 0
        }
    }

    private func handleStopHaptics(currentIndex: Int) {
        if lastStopIndex != currentIndex {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            lastStopIndex = currentIndex
        }
    }

    private func commitInlineEdit() {
        let text = inlineText.filter { $0.isNumber }
        assignActive(text)
        isEditingField = false
        fieldFocused = false
        NSApp.keyWindow?.endEditing(for: nil)
    }

    private func displayTextForActive() -> String {
        let text = activeText
        if text.isEmpty { return "—" }
        return text
    }

    // MARK: - Extracted logic for readability / type-checker performance
    @ViewBuilder
    private func contentRow(containerHeight: CGFloat) -> some View {
        HStack(spacing: 8) {
            toggleButton()
            .font(Theme.Fonts.button)
            .foregroundStyle(.primary)
            .padding(.horizontal, 6)
            Spacer()
            trailingValue(containerHeight: containerHeight)
        }
    }

    @ViewBuilder
    private func toggleButton() -> some View {
        Button(action: {
            withAnimation(Theme.Animations.fastSpring()) {
                toggleActiveDimensionKeepValue()
            }
        }) {
            Text(activeDimension == .width ? String(localized: "Width") : String(localized: "Height"))
                .contentTransition(.opacity)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)
                .padding(.horizontal, 8)
                .frame(height: Theme.Metrics.controlHeight - 10)
                .background(
                    Capsule(style: .continuous)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 2)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(Theme.Animations.fastSpring(), value: activeDimension)
    }

    @ViewBuilder
    private func trailingValue(containerHeight: CGFloat) -> some View {
        Group {
            if isEditingField {
                HStack(spacing: 4) {
                    TextField("", text: $inlineText)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                        .focused($fieldFocused)
                        .onSubmit { commitInlineEdit() }
                        .frame(height: containerHeight)
                        .monospacedDigit()
                        .tint(Color.primary)
                        .onChange(of: inlineText) { _, newValue in
                            let filtered = newValue.filter { $0.isNumber }
                            if filtered != inlineText { inlineText = filtered }
                        }
                        .onAppear {
                            inlineText = activeText
                            DispatchQueue.main.async {
                                fieldFocused = true
                                if let window = NSApp.keyWindow, let textView = window.firstResponder as? NSTextView { textView.selectAll(nil) }
                            }
                        }
                    Text(String(localized: "px"))
                        .padding(.trailing, 10)
                }
            } else {
                HStack(spacing: 4) {
                    Text(displayTextForActive())
                        .font(Theme.Fonts.button)
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .contentShape(Rectangle())
                        .onTapGesture {
                            beginEditing()
                        }
                    Text(String(localized: "px"))
                        .padding(.trailing, 10)
                }
            }
        }
    }

    private func toggleActiveDimensionKeepValue() {
        let value = activeText
        activeDimension = (activeDimension == .width) ? .height : .width
        assignActive(value)
    }
}

