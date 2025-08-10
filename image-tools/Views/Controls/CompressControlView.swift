import SwiftUI
import AppKit

struct CompressControlView: View {
    @ObservedObject var vm: ImageToolsViewModel

    @FocusState private var kbFieldFocused: Bool

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
                            PercentPill(
                                label: String(localized: "Quality"),
                                value01: $vm.compressionPercent,
                                dragStep: 0.05,
                                showsTenPercentHaptics: true,
                                showsFullBoundaryHaptic: true
                            )
                            .transition(.opacity)
                        case .targetKB:
                            kbField(containerSize: size)
                                .transition(.opacity)
                        }
                    }
                }
            }
            .frame(minWidth: controlMinWidth, maxWidth: controlMaxWidth, minHeight: controlHeight, maxHeight: controlHeight)

            CircleIconButton(action: toggleMode) {
                Text(vm.compressionMode == .percent ? String(localized: "KB") : String(localized: "%"))
            }
            .animation(Theme.Animations.spring(), value: vm.compressionMode)
        }
    }

    private func toggleMode() {
        withAnimation(Theme.Animations.spring()) {
            vm.compressionMode = (vm.compressionMode == .percent) ? .targetKB : .percent
        }
    }

    private func kbField(containerSize: CGSize) -> some View {
        let corner = Theme.Metrics.pillCornerRadius(forHeight: containerSize.height)
        return ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(Theme.Colors.controlBackground)
            HStack(spacing: 6) {
                TextField(String(localized: "Target"), text: $vm.compressionTargetKB)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .font(Theme.Fonts.button)
                    .padding(.horizontal, 8)
                    .focused($kbFieldFocused)
                    .onSubmit { NSApp.keyWindow?.endEditing(for: nil); kbFieldFocused = false }
                    .onChange(of: vm.compressionTargetKB) { _, newValue in
                        let digits = newValue.filter { $0.isNumber }
                        if digits != vm.compressionTargetKB { vm.compressionTargetKB = digits }
                    }
                Text(String(localized: "KB"))
                    .font(Theme.Fonts.button)
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
} 
