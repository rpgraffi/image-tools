import SwiftUI

struct MetadataControl: View {
    @EnvironmentObject private var vm: ImageToolsViewModel
    
    var body: some View {
        StrikePillToggle(isOn: $vm.removeMetadata) {
            Text(String(localized: "Metadata"))
        }
        .help(String(localized: vm.removeMetadata ? "Metadata will be removed" : "Preserve metadata"))
    }
} 
