import SwiftUI
import AppKit

/// Reusable W/H pixel fields used by resize controls.
/// - squareLocked: when true, both fields share the same value.
struct PixelFieldsView: View {
    @Binding var widthText: String
    @Binding var heightText: String
    let containerSize: CGSize
    let squareLocked: Bool

    @FocusState private var widthFieldFocused: Bool
    @FocusState private var heightFieldFocused: Bool
    @State private var isSyncing: Bool = false

    var body: some View {
        let width = containerSize.width
        let corner = Theme.Metrics.pillCornerRadius(forHeight: containerSize.height)
        let fieldWidth = (width - 1) / 2
        return HStack(spacing: 0) {
            ZStack(alignment: .trailing) {
                TextField("", text: $widthText)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .font(Theme.Fonts.button)
                    .padding(.horizontal, 8)
                    .frame(width: fieldWidth, height: containerSize.height)
                    .background(
                        UnevenRoundedRectangle(cornerRadii: .init(
                            topLeading: corner,
                            bottomLeading: corner,
                            bottomTrailing: 0,
                            topTrailing: 0
                        ))
                        .fill(Theme.Colors.controlBackground)
                    )
                    .focused($widthFieldFocused)
                    .onSubmit { NSApp.keyWindow?.endEditing(for: nil); widthFieldFocused = false }
                    .onChange(of: widthText) { _, newValue in
                        let digits = newValue.filter { $0.isNumber }
                        if digits != widthText { widthText = digits }
                        if squareLocked { syncFromWidth() }
                    }

                Text(String(localized: "W"))
                    .font(Theme.Fonts.button)
                    .foregroundColor(Color.secondary)
                    .padding(.trailing, 8)
            }

            Spacer().frame(width: 1)

            ZStack(alignment: .trailing) {
                TextField("", text: $heightText)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .font(Theme.Fonts.button)
                    .padding(.horizontal, 8)
                    .frame(width: fieldWidth, height: containerSize.height)
                    .background(
                        UnevenRoundedRectangle(cornerRadii: .init(
                            topLeading: 0,
                            bottomLeading: 0,
                            bottomTrailing: corner,
                            topTrailing: corner
                        ))
                        .fill(Theme.Colors.controlBackground)
                    )
                    .focused($heightFieldFocused)
                    .onSubmit { NSApp.keyWindow?.endEditing(for: nil); heightFieldFocused = false }
                    .onChange(of: heightText) { _, newValue in
                        let digits = newValue.filter { $0.isNumber }
                        if digits != heightText { heightText = digits }
                        if squareLocked { syncFromHeight() }
                    }

                Text(String(localized: "H"))
                    .font(Theme.Fonts.button)
                    .foregroundColor(Color.secondary)
                    .padding(.trailing, 8)
            }
        }
    }

    private func syncFromWidth() {
        if isSyncing { return }
        isSyncing = true
        defer { isSyncing = false }
        if heightText != widthText { heightText = widthText }
    }

    private func syncFromHeight() {
        if isSyncing { return }
        isSyncing = true
        defer { isSyncing = false }
        if widthText != heightText { widthText = heightText }
    }
}


