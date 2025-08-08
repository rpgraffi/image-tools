import SwiftUI

struct RotationFlipControls: View {
    @ObservedObject var vm: ImageToolsViewModel

    var body: some View {
        HStack(spacing: 8) {
            Button {
                vm.rotation = .r0
            } label: { Label("Auto", systemImage: "arrow.triangle.2.circlepath") }
            .help("Auto rotate (resets)")

            Button { vm.rotation = .r270 } label: { Image(systemName: "rotate.left") }
            Button { vm.rotation = .r90 } label: { Image(systemName: "rotate.right") }

            Toggle(isOn: $vm.flipH) { Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right") }
                .toggleStyle(.button)
                .tint(.accentColor)
                .help("Flip Horizontal")
            Toggle(isOn: $vm.flipV) { Image(systemName: "arrow.up.and.down.righttriangle.up.righttriangle.down") }
                .toggleStyle(.button)
                .tint(.accentColor)
                .help("Flip Vertical")
        }
    }
} 