import SwiftUI

struct CircleIconToggle: View {
    @Binding var isOn: Bool
    var highlightedFill: Color = .accentColor
    var normalFill: Color = Theme.Colors.iconBackground
    var highlightedForeground: Color = .white
    var normalForeground: Color = Theme.Colors.iconForeground

    var icon: Image?
    var text: Text?

    init(
        isOn: Binding<Bool>,
        highlightedFill: Color = .accentColor,
        normalFill: Color = Theme.Colors.iconBackground,
        highlightedForeground: Color = .white,
        normalForeground: Color = Theme.Colors.iconForeground,
        icon: Image? = nil,
        text: Text? = nil
    ) {
        self._isOn = isOn
        self.highlightedFill = highlightedFill
        self.normalFill = normalFill
        self.highlightedForeground = highlightedForeground
        self.normalForeground = normalForeground
        self.icon = icon
        self.text = text
    }

    var body: some View {
        let height: CGFloat = Theme.Metrics.controlHeight
        Button(action: { withAnimation(Theme.Animations.spring()) { isOn.toggle() } }) {
            ZStack {
                Circle()
                    .fill(isOn ? highlightedFill : normalFill)
                VStack(spacing: 2) {
                    if let icon {
                        icon
                            .font(Theme.Fonts.button)
                            .foregroundStyle(isOn ? highlightedForeground : normalForeground)
                    }
                    if let text {
                        text
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(isOn ? highlightedForeground : normalForeground)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .padding(6)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .frame(height: height)
        .aspectRatio(1, contentMode: .fit)
        .animation(Theme.Animations.pillFill(), value: isOn)
    }
}


