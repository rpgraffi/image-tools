import SwiftUI

struct PillTextField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.Colors.controlBackground)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .font(Theme.Fonts.button)
                .padding(.horizontal, 8)
        }
    }
} 
