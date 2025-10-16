import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct MainView: View {
    @EnvironmentObject private var vm: ImageToolsViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            TopBar()
            ControlsBar()
            ContentArea()
            BottomBar()
        }
        .frame(minWidth: 680)
        .background(.regularMaterial)
        .ignoresSafeArea(.all, edges: .top)
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
            PaywallView()
        }
    }
}

#Preview {
    MainView()
        .environmentObject(ImageToolsViewModel())
}
