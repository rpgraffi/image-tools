import SwiftUI

struct CircleIconButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.iconBackground)
                label()
                    .font(Theme.Fonts.button)
                    .foregroundStyle(Theme.Colors.iconForeground)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .frame(height: Theme.Metrics.controlHeight)
        .aspectRatio(1, contentMode: .fit)
    }
} 
