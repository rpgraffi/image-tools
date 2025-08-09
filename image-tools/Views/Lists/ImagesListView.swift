import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ImagesListView: View {
    @ObservedObject var vm: ImageToolsViewModel
    @Binding var isDropping: Bool
    let onPickFromFinder: () -> Void
    let onDrop: ([NSItemProvider]) -> Bool

    // Grid config: adaptive columns with a max tile width
    private let tileMaxWidth: CGFloat = 300
    private var columns: [GridItem] { [GridItem(.adaptive(minimum: 220, maximum: tileMaxWidth), spacing: 12, alignment: .top)] }

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
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(vm.newImages + vm.editedImages) { asset in
                                    ImageItem(
                                        asset: asset,
                                        vm: vm,
                                        toggle: { vm.toggleEnable(asset) },
                                        recover: asset.backupURL != nil ? { vm.recoverOriginal(asset) } : nil
                                    )
                                    .contextMenu {
                                        Button("Enable/Disable") { vm.toggleEnable(asset) }
                                        if asset.backupURL != nil { Button("Recover Original") { vm.recoverOriginal(asset) } }
                                    }
                                }
                            }
                            .padding(10)
                        }
                        .contentShape(Rectangle())
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.black.opacity(0.06))
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
                    if vm.newImages.isEmpty && vm.editedImages.isEmpty {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .inset(by: 16)
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
                            .foregroundStyle(isDropping ? Color.accentColor.opacity(0.8) : Color.gray.opacity(0.5))
                    }
                }
                .allowsHitTesting(false)
            )
            // .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
        }
        .padding(8)
        .frame(minWidth: 420)
        .contentShape(Rectangle())
        // New robust drop handling (macOS 13+)
        .dropDestination(for: URL.self, action: { urls, _ in
            vm.addURLs(urls)
            return true
        }, isTargeted: { hovering in
            isDropping = hovering
        })
        .dropDestination(for: NSImage.self, action: { images, _ in
            let tempDir = FileManager.default.temporaryDirectory
            var urls: [URL] = []
            for nsImage in images {
                if let tiff = nsImage.tiffRepresentation,
                   let rep = NSBitmapImageRep(data: tiff),
                   let data = rep.representation(using: .png, properties: [:]) {
                    let url = tempDir.appendingPathComponent("drop_" + UUID().uuidString + ".png")
                    try? data.write(to: url)
                    urls.append(url)
                }
            }
            vm.addURLs(urls)
            return true
        }, isTargeted: { hovering in
            isDropping = hovering
        })
        // Legacy fallback for older systems/providers
        .onDrop(of: [UTType.fileURL.identifier, UTType.image.identifier], isTargeted: $isDropping, perform: onDrop)
    }
}

private struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .gridCellColumns(1)
    }
} 