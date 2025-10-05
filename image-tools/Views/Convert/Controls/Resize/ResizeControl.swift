import SwiftUI
import AppKit

/// Orchestrates resize UI and delegates to specialized sub-controls.
struct ResizeControl: View {
    @EnvironmentObject var vm: ImageToolsViewModel
    
    private let controlMaxWidth: CGFloat = Theme.Metrics.controlMaxWidth
    
    var body: some View {
        HStack(spacing: 4) {
            Group {
                if let sizes = vm.allowedSquareSizes {
                    SquaresResizeControl(allowedSizes: sizes.sorted())
                } else {
                    UnrestrictedResizeControl()
                }
            }
            .frame(minWidth: Theme.Metrics.controlMinWidth)
            
            
            if vm.allowedSquareSizes == nil {
                CircleIconButton(action: toggleMode) {
                    Text(vm.sizeUnit == .percent ? "px" : String(localized: "percent"))
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .animation(Theme.Animations.spring(), value: vm.sizeUnit)
            }
        }
        .frame(height: Theme.Metrics.controlHeight)
        .frame(maxWidth: controlMaxWidth + 36)
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
