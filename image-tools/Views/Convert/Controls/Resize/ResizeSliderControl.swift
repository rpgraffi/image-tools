import SwiftUI
import AppKit

/// Single numeric pixel field with inline dimension toggle ("long" / "high").
/// The field edits either `widthText` or `heightText` based on the active toggle.
struct ResizeSliderControl: View {
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
    
    private func assignActive(_ newValue: String?) {
        let sanitized = newValue?.filter { $0.isNumber } ?? ""
        if activeDimension == .width {
            widthText = sanitized
            heightText = ""
        } else {
            heightText = sanitized
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
                    progress: progress
                )
                contentRow()
                    .allowsHitTesting(!isDragging)
                    .padding(.horizontal, 0)
            }
            .font(Theme.Fonts.button)
            .onTapGesture {
                if !isDragging {
                    beginEditing()
                }
            }
            .scrollGesture(
                totalSteps: stops.count + 1,
                sensitivity: 7.0,
                isEnabled: !isEditingField && !fieldFocused
            ) { steps in
                let current = Int(activeText) ?? 0
                let currentIdx = current == 0 ? stops.count : (stops.firstIndex(of: current) ?? 0)
                let newIdx = (currentIdx + steps).clamped(to: 0...stops.count)
                
                if newIdx >= stops.count {
                    assignActive(nil)
                } else {
                    assignActive(String(stops[newIdx]))
                }
                handleStopHaptics(currentIndex: newIdx)
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
                        let totalStops = stops.count + 1 // include original stop
                        let width = max(containerSize.width, 1)
                        let x = min(max(0, value.location.x), width)
                        let p = Double(x / width)
                        let idx = Int((p * Double(max(totalStops - 1, 1))).rounded())
                        let clampedIdx = min(max(0, idx), max(totalStops - 1, 0))
                        if clampedIdx >= stops.count {
                            assignActive(nil)
                        } else {
                            let side = stops[clampedIdx]
                            assignActive(String(side))
                        }
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
            widthText = ""
        } else {
            activeDimension = .width
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
        if activeText.isEmpty {
            return 1.0
        }
        let currentValue: Int = Int(activeText) ?? 0
        let maxFillProgress: Double = 0.95
        guard stops.count > 1 else { return 0 }
        let denominator = Double(stops.count - 1)
        let indexProgress: Double
        if let idx = stops.firstIndex(of: currentValue) {
            indexProgress = Double(idx) / denominator
        } else {
            let nearestIdx = stops.enumerated().min(by: { abs($0.element - currentValue) < abs($1.element - currentValue) })?.offset ?? 0
            indexProgress = Double(nearestIdx) / denominator
        }
        let clamped = min(max(indexProgress, 0), 1)
        return clamped * maxFillProgress
    }
    
    private func handleStopHaptics(currentIndex: Int) {
        if lastStopIndex != currentIndex {
            Haptics.alignment()
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
    
    private func trailingLabelText() -> String {
        if isEditingField { return String(localized: "px") }
        return activeText.isEmpty ? String(localized: "Original") : String(localized: "px")
    }
    
    // MARK: - Extracted logic for readability / type-checker performance
    @ViewBuilder
    private func contentRow() -> some View {
        HStack(spacing: 8) {
            toggleButton()
                .font(Theme.Fonts.button)
                .foregroundStyle(.primary)
                .padding(.leading, 6)
            trailingValue()
                .frame(maxWidth: .infinity, alignment: .trailing)
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
    private func trailingValue() -> some View {
        Group {
            if isEditingField {
                HStack(spacing: 4) {
                    TextField("_empty_", text: $inlineText)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                        .focused($fieldFocused)
                        .onSubmit { commitInlineEdit() }
                        .fixedSize(horizontal: true, vertical: false)
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
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.trailing, 10)
                }
            } else {
                HStack(spacing: 4) {
                    Text(activeText.isEmpty ? "" : activeText)
                        .font(Theme.Fonts.button)
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .fixedSize(horizontal: true, vertical: false)
                        .contentTransition(.numericText())
                        .onTapGesture {
                            beginEditing()
                        }
                    Text(trailingLabelText())
                        .padding(.trailing, 10)
                        .fixedSize(horizontal: true, vertical: false)
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

