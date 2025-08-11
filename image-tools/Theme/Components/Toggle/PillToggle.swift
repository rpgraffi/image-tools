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
        BasePillToggle(isOn: $isOn, highlightedFill: highlightedFill, normalFill: normalFill) { isOn in
            label()
                .font(Theme.Fonts.button)
                .foregroundStyle(isOn ? Color.white : .primary)
                .padding(.horizontal, 12)
        }
    }
}
