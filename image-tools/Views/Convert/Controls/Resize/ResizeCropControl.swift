import SwiftUI
import AppKit

struct ResizeCropView: View {
    @EnvironmentObject private var vm: ImageToolsViewModel
    
    var body: some View {
        HStack(spacing: 2) {
            // Width field
            InputPillField(
                label: "W",
                text: $vm.resizeWidth,
                cornerRadius: .infinity
            )
            
            // Height field
            InputPillField(
                label: "H",
                text: $vm.resizeHeight,
                cornerRadius: .infinity
            )
        }
        .frame(height: Theme.Metrics.controlHeight)
        .cornerRadius(.infinity)
    }
}

struct InputPillField: View {
    let label: String
    @Binding var text: String
    let cornerRadius: CGFloat
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 2) {
            Text(label)
                .font(Theme.Fonts.button)
                .foregroundColor(text.isEmpty ? .secondary : .primary)
                .padding(.leading, 10)
            
            Spacer()
            
            TextField("px", text: $text)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
                .focused($isFocused)
                .font(Theme.Fonts.button)
                .monospacedDigit()
                .tint(Color.primary)
                .onSubmit {
                    isFocused = false
                    NSApp.keyWindow?.makeFirstResponder(nil)
                }
                .onChange(of: text) { _, newValue in
                    let filtered = newValue.filter { $0.isNumber }
                    if filtered != newValue {
                        text = filtered
                    }
                }
                .frame(alignment: .trailing)
                .padding(.trailing, 10)
        }
        .frame(height: Theme.Metrics.controlHeight)
        .background(text.isEmpty ? Theme.Colors.controlBackground : Color.accentColor)
        .cornerRadius(4)
        .animation(.easeInOut(duration: 0.2), value: text.isEmpty)
        .onTapGesture {
            isFocused = true
        }
    }
}
