import SwiftUI

struct StylizedTooltip: View {
    let text: String

    var body: some View {
        let corner: CGFloat = 8
        Text(text)
            .font(.callout)
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
            .allowsHitTesting(false)
    }
}

private struct StylizedTooltipModifier: ViewModifier {
    let text: String
    let placement: Alignment
    let yOffset: CGFloat
    let showDelay: TimeInterval

    @State private var isHovering: Bool = false
    @State private var shouldShow: Bool = false

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    DispatchQueue.main.asyncAfter(deadline: .now() + showDelay) {
                        if isHovering { withAnimation(Theme.Animations.fastSpring()) { shouldShow = true } }
                    }
                } else {
                    withAnimation(Theme.Animations.fastSpring()) { shouldShow = false }
                }
            }
            .overlay(alignment: placement) {
                if shouldShow {
                    StylizedTooltip(text: text)
                        .transition(.scale.combined(with: .opacity))
                        .offset(y: yOffset)
                }
            }
            .animation(Theme.Animations.fastSpring(), value: shouldShow)
    }
}

extension View {
    func stylizedTooltip(_ text: String,
                         placement: Alignment = .top,
                         yOffset: CGFloat = -8,
                         showDelay: TimeInterval = 0.35) -> some View {
        modifier(StylizedTooltipModifier(text: text,
                                         placement: placement,
                                         yOffset: yOffset,
                                         showDelay: showDelay))
    }
} 