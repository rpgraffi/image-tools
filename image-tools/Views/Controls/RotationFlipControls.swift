import SwiftUI

struct RotationFlipControls: View {
    @ObservedObject var vm: ImageToolsViewModel

    private let controlHeight: CGFloat = Theme.Metrics.controlHeight

    var body: some View {
        HStack(spacing: 8) {
            autoRotatePill()
            flipPill()
        }
    }

    private func autoRotatePill() -> some View {
        let corner = Theme.Metrics.pillCornerRadius(forHeight: controlHeight)
        return Button(action: { vm.rotation = .r0 }) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.2.circlepath")
                Text("Auto")
            }
            .font(.headline)
            .foregroundStyle(.primary)
            .frame(height: controlHeight)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Auto rotate (resets)")
        .background(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(Theme.Colors.controlBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
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
                    .symbolEffect(.wiggle.byLayer, options: .nonRepeating, value: vm.flipH)
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
                    .symbolEffect(.wiggle.byLayer, options: .nonRepeating, value: vm.flipV)
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
        }
        .frame(height: controlHeight)
        .background(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(Theme.Colors.controlBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }
}

 