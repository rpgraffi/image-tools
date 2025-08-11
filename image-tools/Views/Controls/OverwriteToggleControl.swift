import SwiftUI

struct OverwriteToggleControl: View {
    @Binding var isOn: Bool

    var body: some View {
        PillToggle(isOn: $isOn) {
            Text(String(localized: "Overwrite"))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .help(String(localized: "Overwrite originals on save"))
    }
} 
