import SwiftUI

struct OverlayBackground: View {
    let cornerRadius: CGFloat
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Material.thin)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
            )
    }
}

// MARK: - Single Line Badge
struct SingleLineOverlayBadge: View {
    let text: String
    var cornerRadius: CGFloat = 6
    var padding: CGFloat = 6
    
    var body: some View {
        Text(text)
            .font(Theme.Fonts.captionMono)
            .monospaced(true)
            .padding(padding)
            .background(OverlayBackground(cornerRadius: cornerRadius))
    }
}

// MARK: - Two Line Badge
struct TwoLineOverlayBadge: View {
    let topText: String
    let bottomText: String
    var alignment: HorizontalAlignment = .leading
    var cornerRadius: CGFloat = 6
    var padding: CGFloat = 6
    
    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(topText).foregroundStyle(.secondary)
            Text(bottomText).foregroundStyle(.primary)
        }
        .font(Theme.Fonts.captionMono)
        .monospaced(true)
        .padding(padding)
        .background(OverlayBackground(cornerRadius: cornerRadius))
    }
}

