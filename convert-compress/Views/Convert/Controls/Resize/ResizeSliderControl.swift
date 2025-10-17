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
    @State private var hapticTracker = HapticStopTracker()
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
        
        HStack(spacing: 0) {
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
                isEditing = true
            }
            .scrollGesture(
                totalSteps: stops.count + 1,
                sensitivity: 7.0,
                isEnabled: !isEditing
            ) { steps in
                handleScrollGesture(steps: steps, stops: stops)
            }
            .highPriorityGesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        handleDragGesture(value: value, stops: stops)
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
            hapticTracker.reset()
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
    
    // MARK: - Gesture Handlers
    
    private func handleScrollGesture(steps: Int, stops: [Int]) {
        let currentValue = Int(activeText) ?? 0
        let currentIndex = currentValue == 0 ? stops.count : (stops.firstIndex(of: currentValue) ?? 0)
        let newIndex = (currentIndex + steps).clamped(to: 0...stops.count)
        
        applyStopAtIndex(newIndex, stops: stops)
    }
    
    private func handleDragGesture(value: DragGesture.Value, stops: [Int]) {
        isDragging = true
        if isEditing {
            isEditing = false
        }
        guard !stops.isEmpty else { return }
        
        let stopIndex = calculateStopIndex(from: value.location.x, totalStops: stops.count + 1)
        applyStopAtIndex(stopIndex, stops: stops)
    }
    
    private func calculateStopIndex(from xPosition: CGFloat, totalStops: Int) -> Int {
        let width = max(containerSize.width, 1)
        let clampedX = min(max(0, xPosition), width)
        let progress = Double(clampedX / width)
        let rawIndex = Int((progress * Double(max(totalStops - 1, 1))).rounded())
        return min(max(0, rawIndex), max(totalStops - 1, 0))
    }
    
    private func applyStopAtIndex(_ index: Int, stops: [Int]) {
        if index >= stops.count {
            assignActive(nil)
        } else {
            assignActive(String(stops[index]))
        }
        hapticTracker.handleStopChange(currentIndex: index)
    }
    
    // MARK: - Stops and Progress
    
    private func hardcodedStops() -> [Int] {
        ResizeConstants.presetSizes
    }
    
    private func allowedStopsForActiveDimension() -> [Int] {
        let allStops = hardcodedStops()
        guard let base = baseSize, base.width > 0, base.height > 0 else { return allStops }
        
        let maxValue = activeDimension == .width ? Int(base.width) : Int(base.height)
        return allStops.filter { $0 <= maxValue }
    }
    
    private func valueToProgress(stops: [Int]) -> Double {
        guard !stops.isEmpty, stops.count > 1 else { return 0 }
        
        if activeText.isEmpty {
            return 1.0
        }
        
        let currentValue = Int(activeText) ?? 0
        let index: Int
        
        if let exactIndex = stops.firstIndex(of: currentValue) {
            index = exactIndex
        } else {
            index = stops.enumerated()
                .min(by: { abs($0.element - currentValue) < abs($1.element - currentValue) })?
                .offset ?? 0
        }
        
        let normalizedProgress = Double(index) / Double(stops.count - 1)
        return min(max(normalizedProgress, 0), 1) * 0.95
    }
    
    // MARK: - UI Components
    
    @ViewBuilder
    private func contentRow() -> some View {
        HStack(spacing: 8) {
            dimensionToggleButton()
                .padding(.leading, 6)
            
            trailingValue()
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
    
    @ViewBuilder
    private func dimensionToggleButton() -> some View {
        Button {
            withAnimation(Theme.Animations.fastSpring()) {
                let value = activeText
                activeDimension = activeDimension == .width ? .height : .width
                assignActive(value)
            }
        } label: {
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
        HStack(spacing: 4) {
            if isEditing {
                editableTextField()
            } else {
                Text(activeText.isEmpty ? "" : activeText)
                    .font(Theme.Fonts.button)
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .fixedSize(horizontal: true, vertical: false)
                    .animation(nil, value: activeText)
            }
            
            Text(labelText())
                .fixedSize(horizontal: true, vertical: false)
                .padding(.trailing, 10)
        }
        .onChange(of: fieldFocused) { _, isFocused in
            if !isFocused && isEditing {
                isEditing = false
            }
        }
    }
    
    @ViewBuilder
    private func editableTextField() -> some View {
        TextField("", text: activeTextBinding())
            .textFieldStyle(.plain)
            .multilineTextAlignment(.trailing)
            .focused($fieldFocused)
            .frame(minWidth: 30, maxWidth: 60)
            .monospacedDigit()
            .font(Theme.Fonts.button)
            .foregroundStyle(.primary)
            .onAppear {
                fieldFocused = true
                TextFieldUtilities.selectAllText()
            }
            .onSubmit {
                isEditing = false
            }
    }
    
    private func labelText() -> String {
        (isEditing || !activeText.isEmpty) ? String(localized: "px") : String(localized: "Original")
    }
    
    private func activeTextBinding() -> Binding<String> {
        Binding(
            get: { activeText },
            set: { newValue in
                assignActive(newValue.isEmpty ? nil : newValue)
            }
        )
    }
}

