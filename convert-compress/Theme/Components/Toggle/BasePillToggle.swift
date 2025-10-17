import SwiftUI

struct BasePillToggle<Content: View>: View {
    @Binding var isOn: Bool
    var highlightedFill: Color
    var normalFill: Color
    let content: (_ isOn: Bool) -> Content

    init(
        isOn: Binding<Bool>,
        highlightedFill: Color = .accentColor,
        normalFill: Color = Theme.Colors.controlBackground,
        @ViewBuilder content: @escaping (_ isOn: Bool) -> Content
    ) {
        self._isOn = isOn
        self.highlightedFill = highlightedFill
        self.normalFill = normalFill
        self.content = content
    }

    var body: some View {
        let height: CGFloat = Theme.Metrics.controlHeight
        let corner = Theme.Metrics.pillCornerRadius(forHeight: height)
        Button(action: { withAnimation(Theme.Animations.spring()) { isOn.toggle() } }) {
            ZStack {
                content(isOn)
                    .frame(height: height)
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


