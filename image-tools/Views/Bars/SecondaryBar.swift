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
                if vm.isExportingToSource {
                    OverwriteToggleControl(isOn: $vm.overwriteOriginals)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
                ExportDirectoryPill(
                    directory: $vm.exportDirectory,
                    sourceDirectory: vm.sourceDirectory,
                    hasActiveImages: !(vm.newImages.isEmpty && vm.editedImages.isEmpty)
                )
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .animation(Theme.Animations.spring(), value: vm.isExportingToSource)
        }
        .padding(8)
    }
}
