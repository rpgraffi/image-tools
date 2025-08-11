import SwiftUI

struct MetadataControl: View {
    @ObservedObject var vm: ImageToolsViewModel

    var body: some View {
        PillToggle(isOn: $vm.removeMetadata) {
            Text(String(localized: "Metadata"))
                .overlay(
                    Rectangle()
                        .fill(vm.removeMetadata ? Color.white.opacity(0.9) : Color.clear)
                        .frame(height: 2)
                        .offset(y: 0)
                        .scaleEffect(x: vm.removeMetadata ? 1.0 : 0.0, y: 1.0, anchor: .center)
                        .animation(Theme.Animations.spring(), value: vm.removeMetadata)
                )
        }
        .help(String(localized: vm.removeMetadata ? "Metadata will be removed" : "Preserve metadata"))
    }
} 
