import SwiftUI
import AppKit

struct QualityControl: View {
    @EnvironmentObject private var vm: ImageToolsViewModel
    
    @FocusState private var kbFieldFocused: Bool
    
    var body: some View {
        PercentPill(
            label: String(localized: "Quality"),
            value01: $vm.compressionPercent,
            dragStep: 0.05,
            showsTenPercentHaptics: true,
            showsFullBoundaryHaptic: true
        )
        .frame(minWidth: Theme.Metrics.controlMinWidth, maxWidth: Theme.Metrics.controlMaxWidth)
        .frame(height: Theme.Metrics.controlHeight)
        .help(String(localized: "Change image quality"))
    }
}
