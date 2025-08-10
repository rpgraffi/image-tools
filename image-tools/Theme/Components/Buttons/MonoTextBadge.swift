import SwiftUI

struct MonoTextBadge: View {
    let text: String
    let color: Color
    let bgColor: Color

    var body: some View {
        Text(text)
            .font(Theme.Fonts.button).monospaced(true)
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(bgColor)
            )
    }
}
