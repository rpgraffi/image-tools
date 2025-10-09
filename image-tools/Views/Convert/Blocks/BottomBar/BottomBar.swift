import SwiftUI

struct BottomBar: View {
    @EnvironmentObject var vm: ImageToolsViewModel
    
    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                PillButton(role: .destructive) {
                    vm.clearAll()
                } label: {
                    Text(String(localized: "Clear"))
                }
                .help(String(localized: "Clear all images"))
                .disabled(vm.images.isEmpty)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            PrimaryApplyControl()
                .frame(maxWidth: .infinity)
            
            HStack(spacing: 8) {
                ExportDirectoryControl(
                    directory: $vm.exportDirectory,
                    sourceDirectory: vm.sourceDirectory,
                    hasActiveImages: !vm.images.isEmpty
                )
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .animation(Theme.Animations.spring(), value: vm.isExportingToSource)
        }
        .padding(8)
    }
}
