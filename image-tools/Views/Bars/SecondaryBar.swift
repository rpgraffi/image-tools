import SwiftUI

struct SecondaryBar: View {
    @ObservedObject var vm: ImageToolsViewModel
    let onPickFromFinder: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Left column
            HStack(spacing: 8) {
                // PillButton {
                //     vm.addFromPasteboard()
                // } label: {
                //     Label(String(localized: "Paste"), systemImage: "doc.on.clipboard")
                // }
                // CircleIconButton(action: onPickFromFinder) {
                //     Image(systemName: "folder.badge.plus")
                // }
                PillButton(role: .destructive) {
                    vm.clearAll()
                } label: {
                    Text(String(localized: "Clear"))
                }
                .disabled(vm.newImages.isEmpty && vm.editedImages.isEmpty)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            PrimaryApplyControl(
                isDisabled: vm.newImages.isEmpty && vm.editedImages.isEmpty,
                perform: { vm.applyPipeline() }
            ).frame(maxWidth: .infinity)

            // Right column
            HStack(spacing: 8) {
                OverwriteToggleControl(isOn: $vm.overwriteOriginals)
                ExportDirectoryPill(directory: $vm.exportDirectory)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(8)
    }
}
