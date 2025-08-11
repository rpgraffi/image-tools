import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct MainView: View {
    @ObservedObject var vm: ImageToolsViewModel
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
        .onAppear { WindowConfigurator.configureMainWindow() }
        .focusable()
        .focusEffectDisabled()
        .onPasteCommand(of: [.fileURL, .image], perform: handlePaste)
    }

    private func handlePaste(providers: [NSItemProvider]) {
        vm.addProvidersStreaming(providers, batchSize: 16)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard IngestionCoordinator.canHandle(providers: providers) else { return false }
        vm.addProvidersStreaming(providers, batchSize: 16)
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
} 
