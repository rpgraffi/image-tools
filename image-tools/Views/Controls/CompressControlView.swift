import SwiftUI
import AppKit

struct CompressControlView: View {
    @ObservedObject var vm: ImageToolsViewModel

    @FocusState private var kbFieldFocused: Bool

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
    }

    private func toggleMode() {
        withAnimation(Theme.Animations.spring()) {
            vm.compressionMode = (vm.compressionMode == .percent) ? .targetKB : .percent
        }
    }

    private func percentPill(containerSize: CGSize) -> some View {
        let width = containerSize.width
        let corner = Theme.Metrics.pillCornerRadius(forHeight: containerSize.height)
        let progress = Double(min(max(vm.compressionPercent, 0.0), 1.0))
        return ZStack(alignment: .leading) {
            PillBackground(containerSize: containerSize, cornerRadius: corner, progress: progress)

            HStack(spacing: 8) {
                Text("Quality")
                    .font(.headline)
                    .foregroundColor(Color.secondary)

                Spacer(minLength: 0)

                if isEditingPercent {
                    InlinePercentEditor(
                        isEditing: $isEditingPercent,
                        text: $percentString,
                        onCommit: { commitPercentFromString() },
                        onChangeFilter: { newValue in newValue.filter { $0.isNumber } }
                    )
                } else {
                    Text("\(Int(vm.compressionPercent * 100))%")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(Theme.Animations.fastSpring(), value: vm.compressionPercent)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isEditingPercent = true
                            percentString = String(Int(vm.compressionPercent * 100))
                        }
                }
            }
            .padding(.horizontal, 12)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isEditingPercent {
                isEditingPercent = true
                percentString = String(Int(vm.compressionPercent * 100))
            }
        }
        .gesture(DragGesture(minimumDistance: 2)
            .onChanged { value in
                if isEditingPercent { return }
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
