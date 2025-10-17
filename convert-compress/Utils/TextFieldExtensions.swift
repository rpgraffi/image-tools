import AppKit

enum TextFieldUtilities {
    /// Selects all text in the currently focused text field
    static func selectAllText() {
        DispatchQueue.main.async {
            (NSApp.keyWindow?.firstResponder as? NSTextView)?.selectAll(nil)
        }
    }
}

