import SwiftUI

struct PillToggle<LabelContent: View>: View {
    @Binding var isOn: Bool
    let label: () -> LabelContent
    var highlightedFill: Color = .accentColor
    var normalFill: Color = Theme.Colors.controlBackground

    init(isOn: Binding<Bool>, highlightedFill: Color = .accentColor, normalFill: Color = Theme.Colors.controlBackground, @ViewBuilder label: @escaping () -> LabelContent) {
        self._isOn = isOn
        self.highlightedFill = highlightedFill
        self.normalFill = normalFill
        self.label = label
    }

    var body: some View {
        let height: CGFloat = Theme.Metrics.controlHeight
        let corner = Theme.Metrics.pillCornerRadius(forHeight: height)
        Button(action: { withAnimation(Theme.Animations.spring()) { isOn.toggle() } }) {
            ZStack {
                label()
                    .font(Theme.Fonts.button)
                    .foregroundStyle(isOn ? Color.white : .primary)
                    .frame(height: height)
                    .padding(.horizontal, 12)
                    .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(isOn ? highlightedFill : normalFill)
        )
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .animation(Theme.Animations.pillFill(), value: isOn)
    }
} 
