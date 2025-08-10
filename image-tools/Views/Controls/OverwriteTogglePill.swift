import SwiftUI

struct OverwriteTogglePill: View {
    @Binding var isOn: Bool

    var body: some View {
        let height: CGFloat = Theme.Metrics.controlHeight
        let corner = Theme.Metrics.pillCornerRadius(forHeight: height)
        return Button(action: { isOn.toggle() }) {
            Text(String(localized: "Overwrite"))
                .font(.headline)
                .foregroundStyle(isOn ? Color.white : .primary)
                .frame(height: height)
                .padding(.horizontal, 12)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(isOn ? Color.accentColor : Theme.Colors.controlBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .animation(Theme.Animations.pillFill(), value: isOn)
        .help(String(localized: "Overwrite originals on save"))
    }
} 