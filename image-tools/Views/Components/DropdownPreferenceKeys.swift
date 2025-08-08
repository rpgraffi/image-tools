import SwiftUI

struct FormatDropdownAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        // Prefer the most recent anchor if multiple are set in the hierarchy
        value = nextValue() ?? value
    }
} 