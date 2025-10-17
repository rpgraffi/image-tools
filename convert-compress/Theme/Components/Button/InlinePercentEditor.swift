import SwiftUI
import AppKit

struct InlinePercentEditor: View {
    @Binding var isEditing: Bool
    @Binding var text: String
    @FocusState private var fieldFocused: Bool
    
    var minWidth: CGFloat = 28
    var maxWidth: CGFloat = 44
    var font: Font = Theme.Fonts.button
    var onCommit: (() -> Void)?
    
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
                        .onSubmit {
                            commitAndClose()
                        }
                    Text("percent")
                        .font(font)
                        .foregroundStyle(.primary)
                }
                .contentShape(Rectangle())
                .onChange(of: fieldFocused) { _, isFocused in
                    if !isFocused && isEditing {
                        commitAndClose()
                    }
                }
                .onAppear {
                    fieldFocused = true
                    TextFieldUtilities.selectAllText()
                }
            }
        }
    }
    
    private func commitAndClose() {
        onCommit?()
        isEditing = false
        fieldFocused = false
    }
}
