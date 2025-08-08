import SwiftUI

struct BottomRow: View {
    @ObservedObject var vm: ImageToolsViewModel
    let onPickFromFinder: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: { vm.addFromPasteboard() }) {
                Label("Paste", systemImage: "doc.on.clipboard")
            }
            Button(action: { onPickFromFinder() }) {
                Label("Add from Finder", systemImage: "folder.badge.plus")
            }
            Spacer()
            Button(role: .destructive, action: { vm.clearAll() }) {
                Label("Clear", systemImage: "trash")
            }
            .disabled(vm.newImages.isEmpty && vm.editedImages.isEmpty)
        }
        .padding(8)
    }
} 