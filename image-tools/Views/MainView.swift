import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct MainView: View {
    @StateObject private var vm = ImageToolsViewModel()
    @StateObject private var formatDropdown = FormatDropdownController()
    @State private var isDropping: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar of tools
            ControlsBar(vm: vm)
                .padding(12)
                .background(.ultraThinMaterial)

            Divider()

            HStack(spacing: 0) {
                ImagesListView(vm: vm, isDropping: $isDropping, onPickFromFinder: pickFromOpenPanel, onDrop: handleDrop)
            }
        }
        .environmentObject(formatDropdown)
        .overlayPreferenceValue(FormatDropdownAnchorKey.self) { anchor in
            GeometryReader { proxy in
                if let a = anchor, formatDropdown.isOpen {
                    let rect = proxy[a]
                    VStack(spacing: 0) {
                        Rectangle().fill(Color.black.opacity(0.06)).frame(height: 1)
                        FormatDropdownList(vm: vm, onSelect: { fmt in
                            vm.selectedFormat = fmt
                            vm.bumpRecentFormats(fmt)
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
            NSApp.windows.first?.title = "Image Tools"
        }
    }







    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var handled = false
        let group = DispatchGroup()
        var urls: [URL] = []
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
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



#Preview {
    MainView()
} 