import SwiftUI

struct SecondaryBar: View {
    @ObservedObject var vm: ImageToolsViewModel
    let onPickFromFinder: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Left column
            HStack(spacing: 8) {
                PillButton {
                    vm.addFromPasteboard()
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }
                PillButton {
                    onPickFromFinder()
                } label: {
                    Label("Add from Finder", systemImage: "folder.badge.plus")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right column
            HStack(spacing: 8) {
                OverwriteTogglePill(isOn: $vm.overwriteOriginals)
                PillButton(role: .destructive) {
                    vm.clearAll()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .disabled(vm.newImages.isEmpty && vm.editedImages.isEmpty)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(8)
    }
} 