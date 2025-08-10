import SwiftUI

struct RotationFlipControls: View {
    @ObservedObject var vm: ImageToolsViewModel

    @State private var hFlipRotation: Double = 0
    @State private var vFlipRotation: Double = 0

    private let controlHeight: CGFloat = Theme.Metrics.controlHeight

    var body: some View {
        HStack(spacing: 8) {
            flipPill()
        }
    }

    private func flipPill() -> some View {
        let corner = Theme.Metrics.pillCornerRadius(forHeight: controlHeight)
        return HStack(spacing: 0) {
            Button(action: { vm.flipH.toggle() }) {
                Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill")
                    .font(Theme.Fonts.button)
                    .foregroundStyle(vm.flipH ? Color.white : .primary)
                    .frame(height: controlHeight)
                    .padding(.horizontal, 12)
                    .contentShape(Rectangle())
                    .rotation3DEffect(.degrees(hFlipRotation), axis: (x: 0, y: 1, z: 0), perspective: 0.7)
                    .help(String(localized: "Flip Horizontal"))
            }
            .buttonStyle(.plain)
            .background(
                UnevenRoundedRectangle(cornerRadii: .init(
                    topLeading: corner,
                    bottomLeading: corner,
                    bottomTrailing: 0,
                    topTrailing: 0
                ), style: .continuous)
                .fill(Color.accentColor)
                .opacity(vm.flipH ? 1 : 0)
            )
            .onChange(of: vm.flipH) { _, newValue in
                guard newValue else { return }
                withAnimation(.none) { hFlipRotation = 0 }
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.45)) { hFlipRotation = 180 }
                }
            }

            Rectangle()
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 1)
                .padding(.vertical, 6)

            Button(action: { vm.flipV.toggle() }) {
                Image(systemName: "arrow.up.and.down.righttriangle.up.righttriangle.down.fill")
                    .font(Theme.Fonts.button)
                    .foregroundStyle(vm.flipV ? Color.white : .primary)
                    .frame(height: controlHeight)
                    .padding(.horizontal, 12)
                    .contentShape(Rectangle())
                    .rotation3DEffect(.degrees(vFlipRotation), axis: (x: 1, y: 0, z: 0), perspective: 0.7)
                    .help(String(localized: "Flip Vertical"))
            }
            .buttonStyle(.plain)
            .background(
                UnevenRoundedRectangle(cornerRadii: .init(
                    topLeading: 0,
                    bottomLeading: 0,
                    bottomTrailing: corner,
                    topTrailing: corner
                ), style: .continuous)
                .fill(Color.accentColor)
                .opacity(vm.flipV ? 1 : 0)
            )
            .onChange(of: vm.flipV) { _, newValue in
                guard newValue else { return }
                withAnimation(.none) { vFlipRotation = 0 }
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.45)) { vFlipRotation = 180 }
                }
            }
        }
        .frame(height: controlHeight)
        .background(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(Theme.Colors.controlBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }
}

#Preview {
    RotationFlipControls(vm: ImageToolsViewModel())
        .padding()
}

 
