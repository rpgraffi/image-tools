import SwiftUI

struct PillButton<LabelContent: View>: View {
    let role: ButtonRole?
    let action: () -> Void
    let label: () -> LabelContent

    @State private var isHovering: Bool = false

    init(role: ButtonRole? = nil, action: @escaping () -> Void, @ViewBuilder label: @escaping () -> LabelContent) {
        self.role = role
        self.action = action
        self.label = label
    }

    var body: some View {
        let height: CGFloat = Theme.Metrics.controlHeight
        let corner = Theme.Metrics.pillCornerRadius(forHeight: height)
        let destructiveActive = (role == .destructive && isHovering)
        Button(role: role, action: action) {
            label()
                .font(Theme.Fonts.button)
                .foregroundStyle(destructiveActive ? Color.white : .primary)
                .frame(height: height)
                .padding(.horizontal, 12)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(destructiveActive ? Color.red : Theme.Colors.controlBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .onHover { hovering in
            withAnimation(Theme.Animations.pillFill()) { isHovering = hovering }
        }
        .animation(Theme.Animations.pillFill(), value: destructiveActive)
    }
} 
