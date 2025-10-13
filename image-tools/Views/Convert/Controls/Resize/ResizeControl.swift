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
            .help(String(localized: "Change image size"))
            
            
            if vm.allowedSquareSizes == nil {
                CircleIconButton(action: toggleMode) {
                    Image(systemName: vm.resizeMode == .resize ? "crop" : "arrow.down.forward.and.arrow.up.backward")
                        .font(.system(size: 11, weight: .medium))
                }
                .help(vm.resizeMode == .resize ? String(localized: "Switch to crop mode") : String(localized: "Switch to resize mode"))
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .animation(Theme.Animations.spring(), value: vm.resizeMode)
            }
        }
        .frame(height: Theme.Metrics.controlHeight)
        .frame(maxWidth: controlMaxWidth + 36)
        .animation(Theme.Animations.spring(), value: vm.resizeMode)
    }
    
    private func toggleMode() {
        withAnimation(Theme.Animations.spring()) {
            if vm.resizeMode == .resize {
                vm.resizeMode = .crop
            } else {
                vm.resizeMode = .resize
            }
        }
    }
}
