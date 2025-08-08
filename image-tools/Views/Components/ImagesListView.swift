import SwiftUI
import UniformTypeIdentifiers

struct ImagesListView: View {
    @ObservedObject var vm: ImageToolsViewModel
    @Binding var isDropping: Bool
    let onPickFromFinder: () -> Void
    let onDrop: ([NSItemProvider]) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List {
                if !vm.newImages.isEmpty {
                    Section("New Images") {
                        ForEach(vm.newImages) { asset in
                            ImageRow(asset: asset, isEdited: false, vm: vm, toggle: { vm.toggleEnable(asset) }, recover: nil)
                                .contextMenu {
                                    Button("Enable/Disable") { vm.toggleEnable(asset) }
                                }
                        }
                    }
                }
                if !vm.editedImages.isEmpty {
                    Section("Edited Images") {
                        ForEach(vm.editedImages) { asset in
                            ImageRow(asset: asset, isEdited: true, vm: vm, toggle: { vm.toggleEnable(asset) }, recover: { vm.recoverOriginal(asset) })
                                .contextMenu {
                                    Button("Enable/Disable") { vm.toggleEnable(asset) }
                                    if asset.backupURL != nil {
                                        Button("Recover Original") { vm.recoverOriginal(asset) }
                                    }
                                    Button("Move to New") { vm.moveToNew(asset) }
                                }
                        }
                    }
                }
            }
            .listStyle(.inset)

            HStack(spacing: 8) {
                Button { vm.addFromPasteboard() } label: { Label("Paste", systemImage: "doc.on.clipboard") }
                Button { onPickFromFinder() } label: { Label("Add from Finder", systemImage: "folder.badge.plus") }
            }
            .padding(8)
        }
        .frame(minWidth: 420)
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropping, perform: onDrop)
    }
} 