import SwiftUI
import AppKit

struct UnrestrictedResizeControl: View {
    @EnvironmentObject var vm: ImageToolsViewModel
    
    var body: some View {
        ZStack {
            GeometryReader { geo in
                let size = geo.size
                Group {
                    if vm.resizeMode == .resize {
                        ResizeSliderControl(
                            widthText: $vm.resizeWidth,
                            heightText: $vm.resizeHeight,
                            baseSize: basePixelSizeForCurrentSelection(),
                            containerSize: size,
                            squareLocked: false
                        )
                        .transition(.opacity)
                    } else {
                        ResizeCropView()
                            .transition(.opacity)
                    }
                }
            }
        }
    }
    
    private func basePixelSizeForCurrentSelection() -> CGSize? {
        let sizes = vm.images.compactMap { $0.originalPixelSize }
        guard !sizes.isEmpty else { return nil }
        let maxWidth = sizes.map { $0.width }.max() ?? 0
        let maxHeight = sizes.map { $0.height }.max() ?? 0
        return CGSize(width: maxWidth, height: maxHeight)
    }
}


