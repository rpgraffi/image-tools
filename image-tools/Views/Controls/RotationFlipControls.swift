import SwiftUI

struct RotationFlipControls: View {
    @ObservedObject var vm: ImageToolsViewModel

    @State private var flipHActivationTick: Bool = false
    @State private var flipVActivationTick: Bool = false

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
                    .font(.headline)
                    .foregroundStyle(vm.flipH ? Color.white : .primary)
                    .frame(height: controlHeight)
                    .padding(.horizontal, 12)
                    .contentShape(Rectangle())
                    .symbolEffect(.wiggle.byLayer, options: .nonRepeating, value: flipHActivationTick)
                    .help("Flip Horizontal")
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
                if newValue { flipHActivationTick.toggle() }
            }

            Rectangle()
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 1)
                .padding(.vertical, 6)

            Button(action: { vm.flipV.toggle() }) {
                Image(systemName: "arrow.up.and.down.righttriangle.up.righttriangle.down.fill")
                    .font(.headline)
                    .foregroundStyle(vm.flipV ? Color.white : .primary)
                    .frame(height: controlHeight)
                    .padding(.horizontal, 12)
                    .contentShape(Rectangle())
                    .symbolEffect(.wiggle.byLayer, options: .nonRepeating, value: flipVActivationTick)
                    .help("Flip Vertical")
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
                if newValue { flipVActivationTick.toggle() }
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

 
