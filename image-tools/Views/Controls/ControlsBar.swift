import SwiftUI

struct ControlsBar: View {
    @ObservedObject var vm: ImageToolsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                // Left controls
                FormatControlView(vm: vm)
                    .transition(.opacity.combined(with: .scale))

                ResizeControlView(vm: vm)
                    .transition(.opacity.combined(with: .scale))

                CompressControlView(vm: vm)
                    .transition(.opacity.combined(with: .scale))

                RotationFlipControls(vm: vm)

                Spacer(minLength: 8)

                // Right control
                overwriteTogglePill()
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: vm.sizeUnit)
            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: vm.compressionMode)
            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: vm.overwriteOriginals)
        }
        .padding(8)
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
