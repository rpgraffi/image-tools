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
}


