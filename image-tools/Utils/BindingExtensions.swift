import SwiftUI

extension Binding where Value == String {
    /// Returns a binding that filters the string using the provided transform.
    func filtered(by transform: @escaping (String) -> String) -> Binding<String> {
        Binding(
            get: { wrappedValue },
            set: { wrappedValue = transform($0) }
        )
    }
    
    /// Returns a binding that only allows numeric characters.
    func numericOnly() -> Binding<String> {
        filtered { $0.filter(\.isNumber) }
    }
}

