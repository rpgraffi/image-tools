import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct MainView: View {
    @ObservedObject var vm: ImageToolsViewModel
    @EnvironmentObject private var formatDropdown: FormatDropdownController
    @State private var isDropping: Bool = false

    var body: some View {
        ZStack {
            VisualEffectView()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ControlsBar(vm: vm)
                ImagesListView(vm: vm, isDropping: $isDropping, onPickFromFinder: pickFromOpenPanel)
                SecondaryBar(vm: vm, onPickFromFinder: pickFromOpenPanel)
            }
        }
        .overlayPreferenceValue(FormatDropdownAnchorKey.self) { anchor in
            GeometryReader { proxy in
                if let a = anchor, formatDropdown.isOpen {
                    let rect = proxy[a]
                    VStack(spacing: 0) {
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
                            .fill(Material.thin)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .offset(x: rect.minX, y: rect.maxY + 6)
                    .zIndex(5)
                }
            }
        }
        .onAppear { WindowConfigurator.configureMainWindow() }
        .focusable()
        .focusEffectDisabled()
        .onPasteCommand(of: [.fileURL, .image], perform: handlePaste)
    }

    private func handlePaste(providers: [NSItemProvider]) {
        IngestionCoordinator.collectURLs(from: providers) { urls in
            vm.addURLs(urls)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard IngestionCoordinator.canHandle(providers: providers) else { return false }
        IngestionCoordinator.collectURLs(from: providers) { urls in
            vm.addURLs(urls)
        }
        return true
    }

    private func pickFromOpenPanel() {
        IngestionCoordinator.presentOpenPanel { urls in
            vm.addURLs(urls)
        }
    }
}

#Preview {
    MainView(vm: ImageToolsViewModel())
        .environmentObject(FormatDropdownController())
} 
