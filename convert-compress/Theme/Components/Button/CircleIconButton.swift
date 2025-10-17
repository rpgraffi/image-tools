import SwiftUI

struct CircleIconButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label
    var background: Color = Theme.Colors.iconBackground
    var foreground: Color = Theme.Colors.iconForeground
    var size: CGFloat = Theme.Metrics.controlHeight

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(background)
                label()
                    .font(Theme.Fonts.button)
                    .foregroundStyle(foreground)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .frame(height: size)
        .aspectRatio(1, contentMode: .fit)
    }
}
