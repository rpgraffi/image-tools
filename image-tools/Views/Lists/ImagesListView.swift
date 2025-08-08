import SwiftUI
import UniformTypeIdentifiers

struct ImagesListView: View {
    @ObservedObject var vm: ImageToolsViewModel
    @Binding var isDropping: Bool
    let onPickFromFinder: () -> Void
    let onDrop: ([NSItemProvider]) -> Bool

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                let isEmpty = vm.newImages.isEmpty && vm.editedImages.isEmpty
                ZStack {
                    if isEmpty {
                        VStack(spacing: 12) {
                            VStack(spacing: 6) {
                                HStack(spacing: 0) {
                                    Text("Drag or ")
                                    Button(action: { vm.addFromPasteboard() }) {
                                        Text("Paste").underline()
                                    }
                                    .buttonStyle(.plain)
                                    Text(" ")
                                    Text("`Cmd+V`")
                                        .font(.system(.body, design: .monospaced))
                                    Text(" your images here.")
                                }
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)

                                HStack(spacing: 0) {
                                    Text("Or select ")
                                    Button(action: { onPickFromFinder() }) {
                                        Text("Folder").underline()
                                    }
                                    .buttonStyle(.plain)
                                }
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                            }
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .padding(24)
                    } else {
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
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color.black.opacity(0.06))
            )
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(
                ZStack {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
                    if vm.newImages.isEmpty && vm.editedImages.isEmpty {
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .inset(by: 16)
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
                            .foregroundStyle(isDropping ? Color.accentColor.opacity(0.8) : Color.gray.opacity(0.5))
                    }
                }
            )
            // .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
        }
        .padding(8)
        .frame(minWidth: 420)
        .onDrop(of: [UTType.fileURL.identifier, UTType.image.identifier], isTargeted: $isDropping, perform: onDrop)
    }
} 