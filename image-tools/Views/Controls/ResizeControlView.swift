import SwiftUI
import AppKit

struct ResizeControlView: View {
    @ObservedObject var vm: ImageToolsViewModel

    @State private var isEditingPercent: Bool = false
    @State private var localPercent: Int = 100 // 0...100 UI value (rounded)
    @State private var percentString: String = "100"
    @State private var didHapticAtFullResize: Bool = false
    @FocusState private var percentFieldFocused: Bool
    @FocusState private var widthFieldFocused: Bool
    @FocusState private var heightFieldFocused: Bool

    private let controlHeight: CGFloat = Theme.Metrics.controlHeight
    private let controlMinWidth: CGFloat = Theme.Metrics.controlMinWidth
    private let controlMaxWidth: CGFloat = Theme.Metrics.controlMaxWidth

    var body: some View {
        HStack(spacing: 4) {
            // Main control (percent pill or pixel fields)
            ZStack { // fixed footprint for both modes
                GeometryReader { geo in
                    let size = geo.size
                    Group {
                        if vm.sizeUnit == .percent {
                            percentPill(containerSize: size)
                                .transition(.opacity)
                        } else {
                            pixelFields(containerSize: size)
                                .transition(.opacity)
                        }
                    }
                    .frame(width: size.width, height: size.height)
                }
            }
            .frame(minWidth: controlMinWidth, maxWidth: controlMaxWidth, minHeight: controlHeight, maxHeight: controlHeight)

            // Single switch button showing only the alternative mode
            CircleIconButton(action: toggleMode) {
                Text(vm.sizeUnit == .percent ? "px" : "%")
            }
            .frame(minHeight: controlHeight, maxHeight: controlHeight)
            .animation(Theme.Animations.spring(), value: vm.sizeUnit)
        }
        .onAppear {
            localPercent = clampPercent(Int(round(vm.resizePercent * 100)))
            percentString = String(localPercent)
        }
        .onChange(of: vm.sizeUnit) { _, newValue in
            withAnimation(Theme.Animations.spring()) {
                if newValue == .pixels {
                    vm.prefillPixelsIfPossible()
                }
            }
        }
        // Confirm edit when focus leaves the percent field
        .onChange(of: percentFieldFocused) { _, focused in
            if !focused && isEditingPercent {
                commitPercentFromString()
                isEditingPercent = false
            }
            if focused {
                // Select all text when field gains focus (after click processing)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    if percentFieldFocused && isEditingPercent {
                        NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                    }
                }
            }
        }
        .onChange(of: widthFieldFocused) { _, focused in
            if focused {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    if widthFieldFocused {
                        NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                    }
                }
            }
        }
        .onChange(of: heightFieldFocused) { _, focused in
            if focused {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    if heightFieldFocused {
                        NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                    }
                }
            }
        }
    }



    private func toggleMode() {
        withAnimation(Theme.Animations.spring()) {
            if vm.sizeUnit == .percent {
                vm.sizeUnit = .pixels
                vm.prefillPixelsIfPossible()
            } else {
                vm.sizeUnit = .percent
                localPercent = clampPercent(Int(round(vm.resizePercent * 100)))
                percentString = String(localPercent)
            }
        }
    }

    private func percentPill(containerSize: CGSize) -> some View {
        let width = containerSize.width
        let corner = Theme.Metrics.pillCornerRadius(forHeight: containerSize.height)
        let percentProgress = CGFloat(Double(localPercent) / 100.0)
        let fadeStart: CGFloat = 0.95
        let fillOpacity: CGFloat = percentProgress < fadeStart ? 1.0 : max(0.0, (1.0 - (percentProgress - fadeStart) / (1.0 - fadeStart)))
        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(Theme.Colors.controlBackground)
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(LinearGradient(colors: [Theme.Colors.accentGradientStart, Theme.Colors.accentGradientEnd], startPoint: .leading, endPoint: .trailing))
                .opacity(fillOpacity)
                .frame(width: max(0, width * percentProgress))
                .animation(Theme.Animations.pillFill(), value: localPercent)

            HStack(spacing: 8) {
                Text("Resize")
                    .font(.headline)
                    .foregroundColor(Color.secondary)

                Spacer(minLength: 0)

                if isEditingPercent {
                    HStack(spacing: 2) {
                        TextField("", text: $percentString)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .font(.headline)
                            .focused($percentFieldFocused)
                            .frame(minWidth: 28, maxWidth: 44)
                            .onSubmit { commitPercentFromString(); isEditingPercent = false; percentFieldFocused = false; NSApp.keyWindow?.endEditing(for: nil) }
                            .onChange(of: percentString) { _, newValue in
                                // integer-only filtering
                                let digits = newValue.filter { $0.isNumber }
                                if digits != percentString { percentString = digits }
                            }
                        Text("%")
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                    .contentShape(Rectangle())
                } else {
                    Text("\(localPercent)%")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isEditingPercent = true
                            percentString = String(localPercent)
                            percentFieldFocused = true
                        }
                }
            }
            .padding(.horizontal, 12)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isEditingPercent && !percentFieldFocused {
                isEditingPercent = true
                percentString = String(localPercent)
                percentFieldFocused = true
            }
        }
        .gesture(DragGesture(minimumDistance: 2)
            .onChanged { value in
                if isEditingPercent || percentFieldFocused { return }
                let x = min(max(0, value.location.x), width)
                let p = (x / width) * 100
                let rounded = clampPercent(Int(round(p)))
                localPercent = rounded
                vm.resizePercent = Double(localPercent) / 100.0
                if rounded >= 100 && !didHapticAtFullResize {
                    NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
                    didHapticAtFullResize = true
                } else if rounded < 100 && didHapticAtFullResize {
                    didHapticAtFullResize = false
                }
            }
        )
    }

    private func pixelFields(containerSize: CGSize) -> some View {
        let width = containerSize.width
        let corner = Theme.Metrics.pillCornerRadius(forHeight: containerSize.height)
        let fieldWidth = (width - 1) / 2 // 1pt internal divider
        return HStack(spacing: 0) {
            ZStack(alignment: .trailing) {
                TextField("", text: $vm.resizeWidth)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .font(.headline)
                    .padding(.horizontal, 8)
                    .frame(width: fieldWidth, height: containerSize.height)
                    .background(
                        UnevenRoundedRectangle(cornerRadii: .init(
                            topLeading: corner,
                            bottomLeading: corner,
                            bottomTrailing: 0,
                            topTrailing: 0
                        ))
                        .fill(Theme.Colors.controlBackground)
                    )
                    .focused($widthFieldFocused)
                    .onSubmit { NSApp.keyWindow?.endEditing(for: nil); widthFieldFocused = false }
                    .onChange(of: vm.resizeWidth) { _, newValue in
                        // integer-only filtering
                        let digits = newValue.filter { $0.isNumber }
                        if digits != vm.resizeWidth { vm.resizeWidth = digits }
                    }

                Text("W")
                    .font(.headline)
                    .foregroundColor(Color.secondary)
                    .padding(.trailing, 8)
            }

            Spacer().frame(width: 1)

            ZStack(alignment: .trailing) {
                TextField("", text: $vm.resizeHeight)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .font(.headline)
                    .padding(.horizontal, 8)
                    .frame(width: fieldWidth, height: containerSize.height)
                    .background(
                        UnevenRoundedRectangle(cornerRadii: .init(
                            topLeading: 0,
                            bottomLeading: 0,
                            bottomTrailing: corner,
                            topTrailing: corner
                        ))
                        .fill(Theme.Colors.controlBackground)
                    )
                    .focused($heightFieldFocused)
                    .onSubmit { NSApp.keyWindow?.endEditing(for: nil); heightFieldFocused = false }
                    .onChange(of: vm.resizeHeight) { _, newValue in
                        // integer-only filtering
                        let digits = newValue.filter { $0.isNumber }
                        if digits != vm.resizeHeight { vm.resizeHeight = digits }
                    }

                Text("H")
                    .font(.headline)
                    .foregroundColor(Color.secondary)
                    .padding(.trailing, 8)
            }
        }
    }

    private func commitPercentFromString() {
        let parsed = Int(percentString) ?? localPercent
        let clamped = clampPercent(parsed)
        localPercent = clamped
        percentString = String(clamped)
        vm.resizePercent = Double(clamped) / 100.0
    }

    private func clampPercent(_ v: Int) -> Int { max(0, min(100, v)) }
} 
