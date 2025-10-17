import SwiftUI

struct FlipControl: View {
    @EnvironmentObject private var vm: ImageToolsViewModel
    
    @State private var vFlipRotation: Double = 0
    
    private let controlHeight: CGFloat = Theme.Metrics.controlHeight
    
    var body: some View {
        HStack(spacing: 8) {
            flipButton()
        }
    }
    
    private func flipButton() -> some View {
        Button(action: { vm.flipV.toggle() }) {
            ZStack {
                Circle()
                    .fill(vm.flipV ? Color.accentColor : Theme.Colors.iconBackground)
                Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill")
                    .font(Theme.Fonts.button)
                    .foregroundStyle(vm.flipV ? Color.white : Theme.Colors.iconForeground)
                    .rotation3DEffect(.degrees(vFlipRotation), axis: (x: 0, y: 1, z: 0), perspective: 0.7)
                    .help(String(localized: "Flip Horizontal"))
            }
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .frame(height: controlHeight)
        .aspectRatio(1, contentMode: .fit)
        .onChange(of: vm.flipV) { _, newValue in
            guard newValue else { return }
            withAnimation(.none) { vFlipRotation = 0 }
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.45)) { vFlipRotation = 180 }
            }
        }
    }
}

#Preview {
    FlipControl()
        .environmentObject(ImageToolsViewModel())
        .padding()
}

