import SwiftUI
import AppKit

struct MainView: View {
    @StateObject private var vm = ImageToolsViewModel()
    @State private var isDropping: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar of tools
            toolBar
                .padding(12)
                .background(.ultraThinMaterial)

            Divider()

            HStack(spacing: 0) {
                imagesList
                Divider()
                dragDropArea
                    .frame(minWidth: 260)
            }
        }
        .onAppear {
            NSApp.windows.first?.title = "Image Tools"
        }
    }

    private var toolBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Resize
                ResizeControlView(vm: vm)
                    .frame(minWidth: 360)
                    .transition(.opacity.combined(with: .scale))

                Divider().frame(height: 28)

                // Convert
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("Convert")
                        Menu {
                            // Prioritize recent
                            ForEach(vm.recentFormats, id: \.self) { fmt in
                                Button(fmt.displayName) { vm.selectedFormat = fmt }
                            }
                            if !vm.recentFormats.isEmpty { Divider() }
                            ForEach(ImageFormat.allCases.sorted { a, b in
                                if vm.recentFormats.contains(a) { return true }
                                if vm.recentFormats.contains(b) { return false }
                                return a.displayName < b.displayName
                            }, id: \.self) { fmt in
                                Button(fmt.displayName) { vm.selectedFormat = fmt }
                            }
                        } label: {
                            Text(vm.selectedFormat?.displayName ?? "Format")
                                .frame(width: 80)
                        }
                    }
                }

                Divider().frame(height: 28)

                // Compress
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("Compress")
                        Picker("Mode", selection: $vm.compressionMode) {
                            Text("%") .tag(CompressionModeToggle.percent)
                            Text("KB").tag(CompressionModeToggle.targetKB)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)

                        if vm.compressionMode == .percent {
                            HStack(spacing: 4) {
                                Slider(value: $vm.compressionPercent, in: 0.05...1.0, step: 0.01)
                                    .frame(width: 160)
                                Text("\(Int(vm.compressionPercent * 100))%")
                                    .monospacedDigit()
                                    .frame(width: 56, alignment: .trailing)
                            }
                            .transition(.opacity.combined(with: .scale))
                        } else {
                            TextField("Target KB", text: $vm.compressionTargetKB)
                                .frame(width: 100)
                                .textFieldStyle(.roundedBorder)
                                .transition(.opacity.combined(with: .scale))
                        }
                    }
                }

                Divider().frame(height: 28)

                // Rotate & Flip
                HStack(spacing: 8) {
                    Button {
                        vm.rotation = .r0
                    } label: { Label("Auto", systemImage: "arrow.triangle.2.circlepath") }
                        .help("Auto rotate (resets)")

                    Button { vm.rotation = .r270 } label: { Image(systemName: "rotate.left") }
                    Button { vm.rotation = .r90 } label: { Image(systemName: "rotate.right") }

                    Toggle(isOn: $vm.flipH) { Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right") }
                        .toggleStyle(.button)
                        .tint(.accentColor)
                        .help("Flip Horizontal")
                    Toggle(isOn: $vm.flipV) { Image(systemName: "arrow.up.and.down.righttriangle.up.righttriangle.down") }
                        .toggleStyle(.button)
                        .tint(.accentColor)
                        .help("Flip Vertical")
                }

                Divider().frame(height: 28)

                // Remove background
                Toggle(isOn: $vm.removeBackground) { Label("Remove BG", systemImage: "wand.and.stars") }
                    .toggleStyle(.button)
                    .tint(.accentColor)

                Spacer()

                Toggle(isOn: $vm.overwriteOriginals) { Text("Overwrite") }
                    .toggleStyle(.switch)

                Button(role: .none) {
                    vm.applyPipeline()
                } label: {
                    Label("Apply", systemImage: "play.circle.fill")
                }
                .keyboardShortcut(.defaultAction)
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: vm.sizeUnit)
            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: vm.compressionMode)
        }
    }

    private var imagesList: some View {
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
                Button { pickFromOpenPanel() } label: { Label("Add from Finder", systemImage: "folder.badge.plus") }
            }
            .padding(8)
        }
        .frame(minWidth: 420)
    }

    private var dragDropArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isDropping ? Color.accentColor : Color.secondary, style: StrokeStyle(lineWidth: isDropping ? 3 : 2, dash: [6]))
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.06)))
            VStack(spacing: 6) {
                Image(systemName: "square.and.arrow.down.on.square")
                    .font(.system(size: 38))
                    .foregroundStyle(.secondary)
                Text("Drag & Drop Images Here")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .onDrop(of: [kUTTypeFileURL as String], isTargeted: $isDropping) { providers in
            handleDrop(providers: providers)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var handled = false
        let group = DispatchGroup()
        var urls: [URL] = []
        for provider in providers where provider.hasItemConformingToTypeIdentifier(kUTTypeFileURL as String) {
            group.enter()
            provider.loadItem(forTypeIdentifier: kUTTypeFileURL as String, options: nil) { item, _ in
                defer { group.leave() }
                if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    urls.append(url)
                } else if let url = item as? URL {
                    urls.append(url)
                }
            }
            handled = true
        }
        group.notify(queue: .main) {
            vm.addURLs(urls)
        }
        return handled
    }

    private func pickFromOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        if panel.runModal() == .OK {
            vm.addURLs(panel.urls)
        }
    }
}

private struct ImageRow: View {
    let asset: ImageAsset
    let isEdited: Bool
    @ObservedObject var vm: ImageToolsViewModel
    let toggle: () -> Void
    let recover: (() -> Void)?

    var body: some View {
        let preview = vm.previewInfo(for: asset)
        HStack(spacing: 12) {
            if let t = asset.thumbnail {
                Image(nsImage: t)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
                    .cornerRadius(4)
            } else {
                Rectangle().fill(Color.gray.opacity(0.2)).frame(width: 36, height: 36).cornerRadius(4)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(asset.workingURL.lastPathComponent).font(.callout)
                Text(asset.workingURL.deletingLastPathComponent().path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    if let original = asset.originalPixelSize {
                        Text("orig: \(Int(original.width))×\(Int(original.height)))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let target = preview.targetPixelSize {
                        Text("→ \(Int(target.width))×\(Int(target.height)))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let bytes = preview.estimatedOutputBytes {
                        Text("≈ \(formatBytes(bytes))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            if isEdited {
                Text("Edited")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Toggle(isOn: .constant(asset.isEnabled)) { EmptyView() }
                .toggleStyle(.checkbox)
                .onChange(of: asset.isEnabled) { _ in toggle() }
                .help("Enable/Disable for batch")
        }
        .contentShape(Rectangle())
        .overlay(alignment: .trailing) {
            if let recover {
                Button(action: recover) { Image(systemName: "clock.arrow.circlepath") }
                    .buttonStyle(.plain)
                    .padding(.trailing, 4)
                    .help("Recover original")
            }
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        let kb = 1024.0
        let mb = kb * 1024.0
        let b = Double(bytes)
        if b >= mb { return String(format: "%.2f MB", b/mb) }
        if b >= kb { return String(format: "%.0f KB", b/kb) }
        return "\(bytes) B"
    }
}

#Preview {
    MainView()
} 