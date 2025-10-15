import SwiftUI
import AppKit

/// Single numeric pixel field with inline dimension toggle ("width" / "height").
/// Supports dragging, scrolling, and text input to change values.
struct ResizeSliderControl: View {
    @Binding var widthText: String
    @Binding var heightText: String
    let baseSize: CGSize?
    let containerSize: CGSize
    let squareLocked: Bool
    
    private enum ActiveDimension { case width, height }
    
    @State private var activeDimension: ActiveDimension = .width
    @State private var lastStopIndex: Int? = nil
    @State private var isDragging: Bool = false
    @State private var isEditing: Bool = false
    @FocusState private var fieldFocused: Bool
    
    private var activeText: String {
        activeDimension == .width ? widthText : heightText
    }
    
    private func assignActive(_ newValue: String?) {
        if activeDimension == .width {
            widthText = newValue ?? ""
            heightText = ""
        } else {
            heightText = newValue ?? ""
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
            }
            .font(Theme.Fonts.button)
            .onTapGesture {
                if !isDragging {
                    isEditing = true
                }
            }
            .scrollGesture(
                totalSteps: stops.count + 1,
                sensitivity: 7.0,
                isEnabled: !isEditing
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
                        if isEditing {
                            isEditing = false
                        }
                        guard !stops.isEmpty else { return }
                        let totalStops = stops.count + 1
                        let width = max(containerSize.width, 1)
                        let x = min(max(0, value.location.x), width)
                        let p = Double(x / width)
                        let idx = Int((p * Double(max(totalStops - 1, 1))).rounded())
                        let clampedIdx = min(max(0, idx), max(totalStops - 1, 0))
                        
                        if clampedIdx >= stops.count {
                            assignActive(nil)
                        } else {
                            assignActive(String(stops[clampedIdx]))
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
        }
        .onChange(of: activeDimension) {
            lastStopIndex = nil
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
    
    @ViewBuilder
    private func contentRow() -> some View {
        HStack(spacing: 8) {
            Button(action: {
                withAnimation(Theme.Animations.fastSpring()) {
                    let value = activeText
                    activeDimension = (activeDimension == .width) ? .height : .width
                    assignActive(value)
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
            .padding(.leading, 6)
            
            trailingValue()
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
    
    @ViewBuilder
    private func trailingValue() -> some View {
        HStack(spacing: 4) {
            if isEditing {
                TextField("", text: activeTextBinding())
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .focused($fieldFocused)
                    .fixedSize(horizontal: true, vertical: false)
                    .monospacedDigit()
                    .font(Theme.Fonts.button)
                    .foregroundStyle(.primary)
                    .onAppear {
                        fieldFocused = true
                        DispatchQueue.main.async {
                            if let window = NSApp.keyWindow,
                               let textView = window.firstResponder as? NSTextView {
                                textView.selectAll(nil)
                            }
                        }
                    }
                    .onSubmit {
                        isEditing = false
                    }
            } else {
                Text(activeText.isEmpty ? "" : activeText)
                    .font(Theme.Fonts.button)
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .fixedSize(horizontal: true, vertical: false)
                    .contentTransition(.numericText())
            }
            
            Text(labelText())
                .fixedSize(horizontal: true, vertical: false)
                .padding(.trailing, 10)
        }
    }
    
    private func labelText() -> String {
        if isEditing || !activeText.isEmpty {
            return String(localized: "px")
        }
        return String(localized: "Original")
    }
    
    private func activeTextBinding() -> Binding<String> {
        Binding(
            get: { activeText },
            set: { newValue in
                assignActive(newValue.isEmpty ? nil : newValue)
            }
        ).numericOnly()
    }
}

