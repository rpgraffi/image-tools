import SwiftUI

struct SecondaryBar: View {
    @EnvironmentObject var vm: ImageToolsViewModel
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
                .disabled(vm.images.isEmpty)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            PrimaryApplyControl(
                isDisabled: vm.images.isEmpty,
                isInProgress: vm.isExporting,
                progress: vm.exportFraction,
                counterText: vm.isExporting ? "\(vm.exportCompleted)/\(vm.exportTotal)" : nil,
                ingestText: vm.ingestCounterText,
                ingestProgress: vm.ingestFraction,
                perform: { vm.applyPipelineAsync() }
            ).frame(maxWidth: .infinity)

            // Right column
            HStack(spacing: 8) {
                ExportDirectoryPill(
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
