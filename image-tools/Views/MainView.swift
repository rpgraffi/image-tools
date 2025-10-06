import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct MainView: View {
    @EnvironmentObject var vm: ImageToolsViewModel
    @State private var isDropping: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            ControlsBar()
            ContentArea(isDropping: $isDropping, onPickFromFinder: pickFromOpenPanel)
            SecondaryBar(onPickFromFinder: pickFromOpenPanel)
        }
        .frame(minWidth: 680)
        .onAppear {
            WindowConfigurator.configureMainWindow()
            PurchaseManager.shared.configure()
        }
        .focusable()
        .focusEffectDisabled()
        .onCommand(#selector(NSText.paste(_:))) {
            vm.addFromPasteboard()
        }
        .background(.regularMaterial)
        .sheet(isPresented: $vm.isPaywallPresented) {
            PaywallView(
                purchase: PurchaseManager.shared,
                onContinue: { vm.paywallContinueFree() }
            )
        }
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
    MainView()
        .environmentObject(ImageToolsViewModel())
}
