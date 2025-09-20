import SwiftUI

struct FlipControl: View {
    @ObservedObject var vm: ImageToolsViewModel

    @State private var hFlipRotation: Double = 0

    private let controlHeight: CGFloat = Theme.Metrics.controlHeight

    var body: some View {
        HStack(spacing: 8) {
            flipButton()
        }
    }

    private func flipButton() -> some View {
        Button(action: { vm.flipH.toggle() }) {
            ZStack {
                Circle()
                    .fill(vm.flipH ? Color.accentColor : Theme.Colors.iconBackground)
                Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill")
                    .font(Theme.Fonts.button)
                    .foregroundStyle(vm.flipH ? Color.white : Theme.Colors.iconForeground)
                    .rotation3DEffect(.degrees(hFlipRotation), axis: (x: 0, y: 1, z: 0), perspective: 0.7)
                    .help(String(localized: "Flip Horizontal"))
            }
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .frame(height: controlHeight)
        .aspectRatio(1, contentMode: .fit)
        .onChange(of: vm.flipH) { _, newValue in
            guard newValue else { return }
            withAnimation(.none) { hFlipRotation = 0 }
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.45)) { hFlipRotation = 180 }
            }
        }
    }
}

#Preview {
    FlipControl(vm: ImageToolsViewModel())
        .padding()
}

 
