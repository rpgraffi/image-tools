import SwiftUI
import AppKit

/// Single numeric pixel field with inline dimension toggle ("long" / "high").
/// The field edits either `widthText` or `heightText` based on the active toggle.
struct PixelFieldsView: View {
    @Binding var widthText: String
    @Binding var heightText: String
    let baseSize: CGSize?
    let containerSize: CGSize
    let squareLocked: Bool
    
    private enum ActiveDimension { case width, height }
    
    @State private var activeDimension: ActiveDimension = .width
    @FocusState private var fieldFocused: Bool
    @State private var didAcceptWidth: Bool = false
    @State private var didAcceptHeight: Bool = false
    
    private var acceptedForActiveDimension: Bool {
        activeDimension == .width ? didAcceptWidth : didAcceptHeight
    }
    
    var body: some View {
        let corner = Theme.Metrics.pillCornerRadius(forHeight: containerSize.height)
        let textBinding: Binding<String> = Binding<String>(
            get: { activeDimension == .width ? widthText : heightText },
            set: { newValue in
                let digits = newValue.filter { $0.isNumber }
                applyInputToActiveDimension(digits)
            }
        )
        
        return HStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: corner)
                    .fill(acceptedForActiveDimension ? Color.accentColor : Theme.Colors.controlBackground)
                HStack(spacing: 8) {
                    Button(action: {
                        withAnimation(Theme.Animations.fastSpring()) {
                            setActiveDimension(activeDimension == .width ? .height : .width)
                        }
                    }) {
                        Text(activeDimension == .width ? String(localized: "Width") : String(localized: "Height"))
                            .contentTransition(.opacity)
                             .fixedSize(horizontal: true, vertical: false)
                             .layoutPriority(1)
                            .padding(.horizontal, 8)
                            .frame(height: Theme.Metrics.controlHeight - 10)
                            .background(
                                Capsule(style: .continuous)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 2)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .animation(Theme.Animations.fastSpring(), value: activeDimension)
                    
                    .font(Theme.Fonts.button)
                    .foregroundStyle(acceptedForActiveDimension ? Color.white : Color.primary)
                    .padding(.horizontal, 6)
                    
                    Spacer()
                    
                    TextField("", text: textBinding)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                        .focused($fieldFocused)
                        .onSubmit {
                            acceptIfFilledForActiveDimension()
                            NSApp.keyWindow?.endEditing(for: nil)
                            fieldFocused = false
                        }
                        .frame(height: containerSize.height)
                        .monospacedDigit()
                        .tint(acceptedForActiveDimension ? Color.white : Color.primary)
                    
                    Text(String(localized: "px"))
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 10))
                        
                }
                
            }
            .font(Theme.Fonts.button)
            .frame(width: containerSize.width, height: containerSize.height)
            .contentShape(Rectangle())
            .animation(Theme.Animations.pillFill(), value: acceptedForActiveDimension)
        }
        .onAppear {
            initializeActiveDimension()
            refocusAndSelectAll()
        }
		.onChange(of: fieldFocused) { _, isFocused in
			if !isFocused {
                acceptIfFilledForActiveDimension()
            }
        }
		.onChange(of: activeDimension) {
            clearInactiveDimension()
            refocusAndSelectAll()
        }
		.onChange(of: widthText) {
            if fieldFocused { didAcceptWidth = false }
        }
		.onChange(of: heightText) {
            if fieldFocused { didAcceptHeight = false }
        }
    }
    
    private func initializeActiveDimension() {
        if !heightText.isEmpty, (widthText.isEmpty || (Int(widthText) == nil && Int(heightText) != nil)) {
            activeDimension = .height
            // Enforce single-source-of-truth: clear the inactive counterpart.x
            widthText = ""
        } else {
            activeDimension = .width
            // Enforce single-source-of-truth: clear the inactive counterpart.
            heightText = ""
        }
    }
    
    private func refocusAndSelectAll() {
        // Attempt to select all text in the current first responder text field
        // Avoid creating a field editor explicitly; only act when a session exists.
        DispatchQueue.main.async {
            fieldFocused = true
            if let window = NSApp.keyWindow,
               let textView = window.firstResponder as? NSTextView {
                textView.selectAll(nil)
            }
        }
    }
    
    private func acceptIfFilledForActiveDimension() {
        switch activeDimension {
        case .width:
            didAcceptWidth = !widthText.isEmpty
        case .height:
            didAcceptHeight = !heightText.isEmpty
        }
    }
    
    private func clearInactiveDimension() {
        switch activeDimension {
        case .width:
            heightText = ""
        case .height:
            widthText = ""
        }
    }
    
    private func setActiveDimension(_ newValue: ActiveDimension) {
        activeDimension = newValue
        clearInactiveDimension()
        refocusAndSelectAll()
    }
    
    private func applyInputToActiveDimension(_ digits: String) {
        switch activeDimension {
        case .width:
            widthText = digits
            heightText = ""
        case .height:
            heightText = digits
            widthText = ""
        }
    }
}

