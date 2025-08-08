import SwiftUI

struct ControlsBar: View {
    @ObservedObject var vm: ImageToolsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 2) {
                // Resize
                ResizeControlView(vm: vm)
                    .frame(minWidth: 300)
                    .transition(.opacity.combined(with: .scale))

                // Format
                FormatControlView(vm: vm)
                    .frame(minWidth: 160)
                    .transition(.opacity.combined(with: .scale))

                // Compress
                CompressControlView(vm: vm)
                    .frame(minWidth: 300)
                    .transition(.opacity.combined(with: .scale))

                // Rotate & Flip
                RotationFlipControls(vm: vm)

                // Remove background
                Toggle(isOn: $vm.removeBackground) { Label("Remove BG", systemImage: "wand.and.stars") }
                    .toggleStyle(.button)
                    .tint(.accentColor)

                Spacer()

                Toggle(isOn: $vm.overwriteOriginals) { Text("Overwrite") }
                    .toggleStyle(.switch)

                Button(role: .none) {
                    vm.applyPipeline()
                } label: {
                    Label("Apply", systemImage: "play.circle.fill")
                }
                .keyboardShortcut(.defaultAction)
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: vm.sizeUnit)
            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: vm.compressionMode)
        }
    }
} 