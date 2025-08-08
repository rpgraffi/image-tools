import SwiftUI
import AppKit

struct CompressControlView: View {
    @ObservedObject var vm: ImageToolsViewModel

    @FocusState private var kbFieldFocused: Bool
    @FocusState private var percentFieldFocused: Bool

    @State private var isEditingPercent: Bool = false
    @State private var percentString: String = "80"
    @State private var didHapticAtFullQuality: Bool = false
    @State private var lastTenPercentTick: Int? = nil

    private let controlHeight: CGFloat = Theme.Metrics.controlHeight
    private let controlMinWidth: CGFloat = Theme.Metrics.controlMinWidth
    private let controlMaxWidth: CGFloat = Theme.Metrics.controlMaxWidth

    var body: some View {
        HStack(spacing: 4) {
            ZStack {
                GeometryReader { geo in
                    let size = geo.size
                    Group {
                        switch vm.compressionMode {
                        case .percent:
                            percentPill(containerSize: size)
                                .transition(.opacity)
                        case .targetKB:
                            kbField(containerSize: size)
                                .transition(.opacity)
                        }
                    }
                    .frame(width: size.width, height: size.height)
                }
            }
            .frame(minWidth: controlMinWidth, maxWidth: controlMaxWidth, minHeight: controlHeight, maxHeight: controlHeight)

            CircleIconButton(action: toggleMode) {
                Text(vm.compressionMode == .percent ? "KB" : "%")
            }
            .frame(minHeight: controlHeight, maxHeight: controlHeight)
            .animation(Theme.Animations.spring(), value: vm.compressionMode)
        }
        .onAppear {
            percentString = String(Int(vm.compressionPercent * 100))
        }
        .onChange(of: percentFieldFocused) { _, focused in
            if !focused && isEditingPercent {
                commitPercentFromString()
                isEditingPercent = false
            }
            if focused {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    if percentFieldFocused && isEditingPercent {
                        NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                    }
                }
            }
        }
    }

    private func toggleMode() {
        withAnimation(Theme.Animations.spring()) {
            vm.compressionMode = (vm.compressionMode == .percent) ? .targetKB : .percent
        }
    }

    private func percentPill(containerSize: CGSize) -> some View {
        let width = containerSize.width
        let corner = Theme.Metrics.pillCornerRadius(forHeight: containerSize.height)
        let progress = CGFloat(min(max(vm.compressionPercent, 0.0), 1.0))
        let fadeStart: CGFloat = 0.95
        let fillOpacity: CGFloat = progress < fadeStart ? 1.0 : max(0.0, (1.0 - (progress - fadeStart) / (1.0 - fadeStart)))
        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(Theme.Colors.controlBackground)
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(LinearGradient(colors: [Theme.Colors.accentGradientStart, Theme.Colors.accentGradientEnd], startPoint: .leading, endPoint: .trailing))
                .opacity(fillOpacity)
                .frame(width: max(0, width * progress))
                .animation(Theme.Animations.pillFill(), value: vm.compressionPercent)

            HStack(spacing: 8) {
                Text("Quality")
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
                                let digits = newValue.filter { $0.isNumber }
                                if digits != percentString { percentString = digits }
                            }
                        Text("%")
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                    .contentShape(Rectangle())
                } else {
                    Text("\(Int(vm.compressionPercent * 100))%")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isEditingPercent = true
                            percentString = String(Int(vm.compressionPercent * 100))
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
                percentString = String(Int(vm.compressionPercent * 100))
                percentFieldFocused = true
            }
        }
        .gesture(DragGesture(minimumDistance: 2)
            .onChanged { value in
                if isEditingPercent || percentFieldFocused { return }
                let x = min(max(0, value.location.x), width)
                let raw = Double(x / width)
                let stepped = max(0.05, min(1.0, (raw * 20).rounded() / 20.0)) // 5% steps
                vm.compressionPercent = stepped

                // 100% haptic once per drag
                if stepped >= 1.0 && !didHapticAtFullQuality {
                    NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
                    didHapticAtFullQuality = true
                } else if stepped < 1.0 && didHapticAtFullQuality {
                    didHapticAtFullQuality = false
                }

                // Light haptic at each 10% boundary
                let currentTick = Int((stepped * 100).rounded())
                if currentTick % 10 == 0 && currentTick > 0 && currentTick < 100 {
                    if lastTenPercentTick != currentTick {
                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                        lastTenPercentTick = currentTick
                    }
                } else if lastTenPercentTick != nil {
                    // Reset when moving away from the exact boundary
                    lastTenPercentTick = nil
                }
            }
        )
    }

    private func kbField(containerSize: CGSize) -> some View {
        let corner = Theme.Metrics.pillCornerRadius(forHeight: containerSize.height)
        return ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(Theme.Colors.controlBackground)
            HStack(spacing: 6) {
                TextField("Target", text: $vm.compressionTargetKB)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .font(.headline)
                    .padding(.horizontal, 8)
                    .focused($kbFieldFocused)
                    .onSubmit { NSApp.keyWindow?.endEditing(for: nil); kbFieldFocused = false }
                    .onChange(of: vm.compressionTargetKB) { _, newValue in
                        let digits = newValue.filter { $0.isNumber }
                        if digits != vm.compressionTargetKB { vm.compressionTargetKB = digits }
                    }
                Text("KB")
                    .font(.headline)
                    .foregroundColor(Color.secondary)
            }
            .padding(.horizontal, 12)
        }
        .onChange(of: kbFieldFocused) { _, focused in
            if focused {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    if kbFieldFocused {
                        NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                    }
                }
            }
        }
    }

    private func commitPercentFromString() {
        let parsed = Int(percentString) ?? Int(vm.compressionPercent * 100)
        let clamped = max(5, min(100, parsed))
        percentString = String(clamped)
        vm.compressionPercent = Double(clamped) / 100.0
    }
} 
