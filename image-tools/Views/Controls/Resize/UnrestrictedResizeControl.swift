import SwiftUI
import AppKit

struct UnrestrictedResizeControl: View {
    @ObservedObject var vm: ImageToolsViewModel

    var body: some View {
        ZStack {
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
                        PixelFieldsView(
                            widthText: $vm.resizeWidth,
                            heightText: $vm.resizeHeight,
                            baseSize: basePixelSizeForCurrentSelection(),
                            containerSize: size,
                            squareLocked: false
                        )
                            .transition(.opacity)
                    }
                }
                .frame(width: size.width, height: size.height)
            }
        }
    }

    private func basePixelSizeForCurrentSelection() -> CGSize? {
        if let firstEnabled = vm.images.first(where: { $0.isEnabled }), let s = firstEnabled.originalPixelSize { return s }
        return vm.images.first?.originalPixelSize
    }
}


