import SwiftUI

struct ControlsBar: View {
    @EnvironmentObject var vm: ImageToolsViewModel

    var body: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 16) {
                // Left controls
                FormatControl()
                    .transition(.opacity.combined(with: .scale))

                if shouldShowResize {
                    ResizeControl()
                        .transition(.opacity.combined(with: .scale))
                }

                if shouldShowCompression {
                    CompressControl()
                        .transition(.opacity.combined(with: .scale))
                }

                FlipControl()
                BackgroundRemovalControl()
                if shouldShowMetadata {
                    MetadataControl()
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: vm.sizeUnit)
            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: vm.overwriteOriginals)
            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: vm.removeMetadata)
            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: vm.allowedSquareSizes)
            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: shouldShowResize)
            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: shouldShowCompression)
            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: shouldShowMetadata)
        }
        .padding(.bottom, 8)
        .padding(.horizontal, 8)
    }

    private var selectedFormatCaps: FormatCapabilities? {
        guard let f = vm.selectedFormat else { return nil }
        return ImageIOCapabilities.shared.capabilities(for: f)
    }

    private var shouldShowCompression: Bool {
        if let f = vm.selectedFormat {
            return ImageIOCapabilities.shared.capabilities(for: f).supportsQuality
        }
        // No format selected: allow generic compression for lossy default (PNG fallback is lossless; quality would be ignored)
        return true
    }

    private var shouldShowResize: Bool {
        return true
    }

    private var shouldShowMetadata: Bool {
        if let f = vm.selectedFormat {
            return ImageIOCapabilities.shared.capabilities(for: f).supportsMetadata
        }
        return true
    }

} 
