import SwiftUI

struct ControlsBar: View {
    @ObservedObject var vm: ImageToolsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                // Left controls
                FormatControl(vm: vm)
                    .transition(.opacity.combined(with: .scale))

                if shouldShowResize {
                    ResizeControl(vm: vm)
                        .transition(.opacity.combined(with: .scale))
                }

                if shouldShowCompression {
                    CompressControl(vm: vm)
                        .transition(.opacity.combined(with: .scale))
                }

                FlipControl(vm: vm)
                if shouldShowMetadata {
                    MetadataControl(vm: vm)
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: vm.sizeUnit)
            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: vm.compressionMode)
            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: vm.overwriteOriginals)
            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: vm.removeMetadata)
            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: shouldShowResize)
            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: shouldShowCompression)
            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: shouldShowMetadata)
        }
        .padding(8)
    }

    private var selectedFormatCaps: FormatCapabilities? {
        guard let f = vm.selectedFormat else { return nil }
        return ImageIOCapabilities.shared.capabilities(for: f)
    }

    private var shouldShowCompression: Bool {
        // Show compression control only if the eventual format supports quality or if user targets KB
        if vm.compressionMode == .targetKB { return true }
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
