import AppKit
import SwiftUI

struct ComparisonSplitHandle: View {
    @State private var isHovering: Bool = false
    private var currentHandleSize: CGFloat {
        (isHovering) ? 46 : 34
    }
    
    var body: some View {
        if #available(macOS 26.0, *) {
            ZStack {
                GlassEffectContainer {
                    Rectangle()
                        .glassEffect(.clear)
                        .frame(width: 3)
                        .frame(maxWidth: .infinity)
                    
                    Circle()
                        .glassEffect(.clear)
                        .frame(width: currentHandleSize, height: currentHandleSize)
                        .onHover { hovering in
                            isHovering = hovering
                            if hovering {
                                NSCursor.frameResize(position: .right, directions: .all).push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                }
            }.animation(Theme.Animations.fastSpring(), value: isHovering)
        } else {
            ZStack {
                Rectangle()
                    .fill(.regularMaterial)
                    .frame(width: 3)
                    .frame(maxWidth: .infinity)
                    .overlay(
                        Rectangle()
                            .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
                    )
                Circle()
                    .fill(.regularMaterial)
                    .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
                    .frame(width: currentHandleSize, height: currentHandleSize)
                    .overlay(
                        Image(
                            systemName: "chevron.compact.left.chevron.compact.right"
                        )
                        .font(
                            .system(size: 14, weight: .semibold, design: .rounded)
                        )
                        .foregroundStyle(.primary)
                    )
                    .onHover { hovering in isHovering = hovering }
            }.animation(Theme.Animations.fastSpring(), value: isHovering)
        }
    }
}
