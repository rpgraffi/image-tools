import SwiftUI

enum Theme {
    struct Metrics {
        static let controlHeight: CGFloat = 36
        static let controlMinWidth: CGFloat = 80
        static let controlMaxWidth: CGFloat = 220

        static func pillCornerRadius(forHeight height: CGFloat) -> CGFloat { height / 2 }
    }

    struct Colors {
        static let controlBackground: Color = Color.secondary.opacity(0.12)
        static let accentGradientStart: Color = Color.accentColor.opacity(0.25)
        static let accentGradientEnd: Color = Color.accentColor.opacity(0.6)

        static let iconForeground: Color = .primary
        static let iconBackground: Color = Color.secondary.opacity(0.12)

        static let fieldAffordanceLabel: Color = Color.secondary.opacity(0.5)
    }

    struct Animations {
        static func spring() -> Animation { .spring(response: 0.6, dampingFraction: 0.85) }
        static func pillFill() -> Animation { .spring(response: 0.7, dampingFraction: 0.85) }
    }
} 