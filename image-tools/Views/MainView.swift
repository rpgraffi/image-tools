import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct MainView: View {
    @StateObject private var vm = ImageToolsViewModel()
    @StateObject private var formatDropdown = FormatDropdownController()
    @State private var isDropping: Bool = false

    var body: some View {
        ZStack {
            VisualEffectView()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ControlsBar(vm: vm)
                ImagesListView(vm: vm, isDropping: $isDropping, onPickFromFinder: pickFromOpenPanel, onDrop: handleDrop)
                BottomRow(vm: vm, onPickFromFinder: pickFromOpenPanel)
            }
        }
        .environmentObject(formatDropdown)
        .overlayPreferenceValue(FormatDropdownAnchorKey.self) { anchor in
            GeometryReader { proxy in
                if let a = anchor, formatDropdown.isOpen {
                    let rect = proxy[a]
                    VStack(spacing: 0) {
                        Rectangle().fill(Color.black.opacity(0.06)).frame(height: 1)
                                                 FormatDropdownList(vm: vm, onSelect: { (fmt: ImageFormat?) in
                            vm.selectedFormat = fmt
                            if let f = fmt { vm.bumpRecentFormats(f) }
                            withAnimation(Theme.Animations.spring()) { formatDropdown.isOpen = false }
                            formatDropdown.query = ""
                        })
                        .environmentObject(formatDropdown)
                    }
                    .frame(width: Theme.Metrics.controlMaxWidth)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .offset(x: rect.minX, y: rect.maxY + 6)
                    .zIndex(1000)
                }
            }
        }
        .onAppear {
            if let window = NSApp.windows.first {
                window.title = "Image Tools"
                window.isOpaque = false
                window.backgroundColor = .clear
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
                window.styleMask.insert(.fullSizeContentView)
            }
        }
        // Enable Edit > Paste and Cmd+V for images and file URLs
        .onPasteCommand(of: [.fileURL, .image], perform: handlePaste(providers:))
    }

    private func handlePaste(providers: [NSItemProvider]) {
        _ = handleDrop(providers: providers)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var handled = false
        let group = DispatchGroup()
        var urls: [URL] = []
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                handled = true
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        urls.append(url)
                    } else if let url = item as? URL {
                        urls.append(url)
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                handled = true
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    let tempDir = FileManager.default.temporaryDirectory
                    func writeImage(_ nsImage: NSImage) {
                        if let tiff = nsImage.tiffRepresentation,
                           let rep = NSBitmapImageRep(data: tiff),
                           let data = rep.representation(using: .png, properties: [:]) {
                            let url = tempDir.appendingPathComponent("paste_" + UUID().uuidString + ".png")
                            try? data.write(to: url)
                            urls.append(url)
                        }
                    }
                    if let data = item as? Data, let image = NSImage(data: data) {
                        writeImage(image)
                    } else if let image = item as? NSImage {
                        writeImage(image)
                    }
                }
            }
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

#Preview {
    MainView()
} 
