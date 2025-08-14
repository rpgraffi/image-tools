import SwiftUI
import AppKit

struct CompressControl: View {
    @ObservedObject var vm: ImageToolsViewModel

    @FocusState private var kbFieldFocused: Bool

    private let controlHeight: CGFloat = Theme.Metrics.controlHeight
    private let controlMinWidth: CGFloat = Theme.Metrics.controlMinWidth
    private let controlMaxWidth: CGFloat = Theme.Metrics.controlMaxWidth

    var body: some View {
        HStack(spacing: 4) {
            ZStack {
                PercentPill(
                    label: String(localized: "Quality"),
                    value01: $vm.compressionPercent,
                    dragStep: 0.05,
                    showsTenPercentHaptics: true,
                    showsFullBoundaryHaptic: true
                )
            }
            .frame(minWidth: controlMinWidth, maxWidth: controlMaxWidth, minHeight: controlHeight, maxHeight: controlHeight)

            
        }
    }

    
} 
