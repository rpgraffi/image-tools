import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct MainView: View {
    @EnvironmentObject var vm: ImageToolsViewModel
    
    var body: some View {
        VStack() {
            ControlsBar()
            ContentArea()
            BottomBar()
        }
        .frame(minWidth: 680)
        .background(.regularMaterial)
        .onAppear {
            WindowConfigurator.configureMainWindow()
            PurchaseManager.shared.configure()
        }
        .focusable()
        .focusEffectDisabled()
        .onCommand(#selector(NSText.paste(_:))) {
            vm.addFromPasteboard()
        }
        .sheet(isPresented: $vm.isPaywallPresented) {
            PaywallView(
                purchase: PurchaseManager.shared,
                onContinue: { vm.paywallContinueFree() }
            )
        }
    }
}

#Preview {
    MainView()
        .environmentObject(ImageToolsViewModel())
}
