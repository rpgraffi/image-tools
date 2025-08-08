import SwiftUI
import AppKit

struct InlinePercentEditor: View {
    @Binding var isEditing: Bool
    @Binding var text: String
    @FocusState private var fieldFocused: Bool

    var minWidth: CGFloat = 28
    var maxWidth: CGFloat = 44
    var font: Font = .headline
    var onCommit: (() -> Void)?
    var onChangeFilter: ((String) -> String)?

    var body: some View {
        Group {
            if isEditing {
                HStack(spacing: 2) {
                    TextField("", text: $text)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                        .font(font)
                        .focused($fieldFocused)
                        .frame(minWidth: minWidth, maxWidth: maxWidth)
                        .onSubmit { onCommit?(); isEditing = false; fieldFocused = false; NSApp.keyWindow?.endEditing(for: nil) }
                        .onChange(of: text) { _, newValue in
                            if let filter = onChangeFilter {
                                let filtered = filter(newValue)
                                if filtered != text { text = filtered }
                            }
                        }
                    Text("%")
                        .font(font)
                        .foregroundStyle(.primary)
                }
                .contentShape(Rectangle())
                .onChange(of: fieldFocused) { _, focused in
                    if !focused && isEditing {
                        onCommit?()
                        isEditing = false
                    }
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        if isEditing && !fieldFocused {
                            fieldFocused = true
                            NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                        }
                    }
                }
            }
        }
    }
} 