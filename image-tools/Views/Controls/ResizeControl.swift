import SwiftUI
import AppKit

struct ResizeControl: View {
    @ObservedObject var vm: ImageToolsViewModel

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
                            PercentPill(
                                label: String(localized: "Resize"),
                                value01: $vm.resizePercent,
                                dragStep: 0.01,
                                showsTenPercentHaptics: false,
                                showsFullBoundaryHaptic: true
                            )
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
                Text(vm.sizeUnit == .percent ? String(localized: "px") : String(localized: "%"))
            }
            .animation(Theme.Animations.spring(), value: vm.sizeUnit)
        }
        .onChange(of: vm.sizeUnit) { _, newValue in
            withAnimation(Theme.Animations.spring()) {
                if newValue == .pixels {
                    vm.prefillPixelsIfPossible()
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
            }
        }
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
                    .font(Theme.Fonts.button)
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

                Text(String(localized: "W"))
                    .font(Theme.Fonts.button)
                    .foregroundColor(Color.secondary)
                    .padding(.trailing, 8)
            }

            Spacer().frame(width: 1)

            ZStack(alignment: .trailing) {
                TextField("", text: $vm.resizeHeight)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .font(Theme.Fonts.button)
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

                Text(String(localized: "H"))
                    .font(Theme.Fonts.button)
                    .foregroundColor(Color.secondary)
                    .padding(.trailing, 8)
            }
        }
    }
} 
