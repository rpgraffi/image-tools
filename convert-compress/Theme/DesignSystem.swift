import SwiftUI

enum Theme {
    struct Metrics {
        static let controlHeight: CGFloat = 36
        static let controlMinWidth: CGFloat = 130
        static let controlMaxWidth: CGFloat = 200

        static func pillCornerRadius(forHeight height: CGFloat) -> CGFloat { height / 2 }
    }

    struct Colors {
        static let controlBackground: Color = Color.secondary.opacity(0.12)
        static let accentGradientStart: Color = Color.accentColor.opacity(0.5)
        static let accentGradientEnd: Color = Color.accentColor.opacity(0.9)

        static let iconForeground: Color = .primary
        static let iconBackground: Color = Color.secondary.opacity(0.12)
    }

    struct Animations {
        static func spring() -> Animation { .spring(response: 0.6, dampingFraction: 0.85) }
        static func fastSpring() -> Animation { .spring(response: 0.3, dampingFraction: 0.85) }
        static func pillFill() -> Animation { .spring(response: 0.7, dampingFraction: 0.85) }
    }
    
    struct Fonts {
        static let button: Font = .system(size: 14, weight: .medium)
        static let captionMono: Font = .system(size: 10, weight: .regular).monospaced()
    }
}
