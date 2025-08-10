import SwiftUI

struct PrimaryApplyButton: View {
    let isDisabled: Bool
    let perform: () -> Void

    var body: some View {
        let height: CGFloat = max(Theme.Metrics.controlHeight, 40)
        let corner = Theme.Metrics.pillCornerRadius(forHeight: height)
        Button(role: .none) {
            perform()
        } label: {
            Label("Apply", systemImage: "play.fill")
                .font(.headline)
                .foregroundStyle(Color.white)
                .frame(minWidth: 120, minHeight: height)
                .padding(.horizontal, 20)
                .contentShape(Rectangle())
        }
        .keyboardShortcut(.defaultAction)
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(Color.accentColor)
        )
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .disabled(isDisabled)
        .shadow(color: Color.accentColor.opacity(0.25), radius: 8, x: 0, y: 2)
        .help("Apply processing pipeline")
    }
} 
