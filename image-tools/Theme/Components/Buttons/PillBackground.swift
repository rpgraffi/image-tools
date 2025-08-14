import SwiftUI

struct PillBackground: View {
    let containerSize: CGSize
    let cornerRadius: CGFloat
    let progress: Double // 0...1
    var fadeStart: Double = 0.95

    var body: some View {
        let width = containerSize.width
        let clampedProgress = max(0.0, min(1.0, progress))
        let p = CGFloat(clampedProgress)
        let fadeStartCGFloat = CGFloat(fadeStart)
        let fillOpacity: CGFloat = p < fadeStartCGFloat
            ? 1.0
            : max(0.0, (1.0 - (p - fadeStartCGFloat) / (1.0 - fadeStartCGFloat)))

        return ZStack(alignment: .leading) {
            Rectangle()
                .fill(Theme.Colors.controlBackground)

            Rectangle()
                .fill(Color.accentColor)
                .opacity(fillOpacity)
                .frame(width: max(0, width * p))
                .animation(Theme.Animations.pillFill(), value: clampedProgress)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
} 
