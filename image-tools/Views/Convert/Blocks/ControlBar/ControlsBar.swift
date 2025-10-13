import SwiftUI

struct ControlsBar: View {
    @EnvironmentObject var vm: ImageToolsViewModel
    
    var body: some View {
        HStack(spacing: 16) {
            FormatControl()
                .transition(.opacity.combined(with: .scale))
            
            ResizeControl()
                .transition(.opacity.combined(with: .scale))
            
            if shouldShowCompression {
                CompressControl()
                    .transition(.opacity.combined(with: .scale))
            }
            
            FlipControl()
            RemoveBackgroundControl()
            
            if shouldShowMetadata {
                MetadataControl()
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: vm.selectedFormat)
        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: vm.resizeMode)
        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: vm.overwriteOriginals)
        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: vm.removeMetadata)
        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: vm.allowedSquareSizes)
        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: shouldShowCompression)
        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: shouldShowMetadata)
        .padding(.bottom, 8)
        .padding(.horizontal, 8)
    }
    
    private var shouldShowCompression: Bool {
        if let f = vm.selectedFormat {
            return ImageIOCapabilities.shared.capabilities(for: f).supportsQuality
        }
        return true
    }
    
    private var shouldShowMetadata: Bool {
        if let f = vm.selectedFormat {
            return ImageIOCapabilities.shared.capabilities(for: f).supportsMetadata
        }
        return true
    }
    
}

