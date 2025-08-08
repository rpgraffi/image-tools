import SwiftUI

struct ControlsBar: View {
    @ObservedObject var vm: ImageToolsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                // Format
                FormatControlView(vm: vm)
                    .transition(.opacity.combined(with: .scale))

                // Resize
                ResizeControlView(vm: vm)
                    .transition(.opacity.combined(with: .scale))

                // Compress
                CompressControlView(vm: vm)
                    .transition(.opacity.combined(with: .scale))

                // Rotate & Flip
                RotationFlipControls(vm: vm)

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
        .padding(8)
    }
} 
