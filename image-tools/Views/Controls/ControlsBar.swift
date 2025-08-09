import SwiftUI

struct ControlsBar: View {
    @ObservedObject var vm: ImageToolsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                // Left controls
                FormatControlView(vm: vm)
                    .transition(.opacity.combined(with: .scale))

                if shouldShowResize {
                    ResizeControlView(vm: vm)
                        .transition(.opacity.combined(with: .scale))
                }

                if shouldShowCompression {
                    CompressControlView(vm: vm)
                        .transition(.opacity.combined(with: .scale))
                }

                RotationFlipControls(vm: vm)

                Spacer(minLength: 8)

                // Right controls
                if shouldShowMetadata { MetadataControlView(vm: vm) }
                overwriteTogglePill()
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: vm.sizeUnit)
            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: vm.compressionMode)
            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: vm.overwriteOriginals)
            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: vm.removeMetadata)
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
        // For Apple-native formats resizing is unrestricted in our capabilities model
        if let f = vm.selectedFormat {
            return !ImageIOCapabilities.shared.capabilities(for: f).resizeRestricted
        }
        return true
    }

    private var shouldShowMetadata: Bool {
        if let f = vm.selectedFormat {
            return ImageIOCapabilities.shared.capabilities(for: f).supportsMetadata
        }
        return true
    }

    private func overwriteTogglePill() -> some View {
        let height: CGFloat = Theme.Metrics.controlHeight
        let corner = Theme.Metrics.pillCornerRadius(forHeight: height)
        return Button(action: { vm.overwriteOriginals.toggle() }) {
            Text("Overwrite")
                .font(.headline)
                .foregroundStyle(vm.overwriteOriginals ? Color.white : .primary)
                .frame(height: height)
                .padding(.horizontal, 12)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(vm.overwriteOriginals ? Color.accentColor : Theme.Colors.controlBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .animation(Theme.Animations.pillFill(), value: vm.overwriteOriginals)
        .help("Overwrite originals on save")
    }
} 
