import SwiftUI
import AppKit

/// Orchestrates resize UI and delegates to specialized sub-controls.
struct ResizeControl: View {
    @ObservedObject var vm: ImageToolsViewModel

    private let controlHeight: CGFloat = Theme.Metrics.controlHeight
    private let controlMinWidth: CGFloat = Theme.Metrics.controlMinWidth
    private let controlMaxWidth: CGFloat = Theme.Metrics.controlMaxWidth

    var body: some View {
        HStack(spacing: 4) {
            Group {
                if let sizes = vm.allowedSquareSizes {
                    SquaresResizeControl(vm: vm, allowedSizes: sizes.sorted())
                } else {
                    UnrestrictedResizeControl(vm: vm)
                }
            }
            .frame(minWidth: controlMinWidth, maxWidth: controlMaxWidth, minHeight: controlHeight, maxHeight: controlHeight)

            if vm.allowedSquareSizes == nil {
                CircleIconButton(action: toggleMode) {
                    Text(vm.sizeUnit == .percent ? String(localized: "px") : String(localized: "%"))
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.9)),
                    removal: .opacity.combined(with: .scale(scale: 0.9))
                ))
                .animation(Theme.Animations.spring(), value: vm.sizeUnit)
            }
        }
                .animation(Theme.Animations.spring(), value: vm.sizeUnit)
        .onChange(of: vm.sizeUnit) { _, newValue in
            withAnimation(Theme.Animations.spring()) {
                vm.handleSizeUnitToggle(to: newValue)
            }
        }
    }

    private func toggleMode() {
        withAnimation(Theme.Animations.spring()) {
            if vm.sizeUnit == .percent {
                vm.sizeUnit = .pixels
            } else {
                vm.sizeUnit = .percent
            }
        }
    }
}
