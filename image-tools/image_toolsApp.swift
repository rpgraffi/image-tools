import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate { 
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    static var sharedViewModel: ImageToolsViewModel? {
        didSet {
            guard let vm = sharedViewModel, !pendingURLs.isEmpty else { return }
            processPendingURLs(with: vm)
        }
    }
    
    private static var pendingURLs: [URL] = []
    
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let vm = AppDelegate.sharedViewModel else {
            AppDelegate.pendingURLs.append(contentsOf: urls)
            return
        }
        
        processURLs(urls, with: vm)
    }
    
    private static func processPendingURLs(with vm: ImageToolsViewModel) {
        Task { @MainActor in
            let urls = pendingURLs
            pendingURLs.removeAll()
            let expandedURLs = urls.flatMap { IngestionCoordinator.expandToSupportedImageURLs(from: $0) }
            vm.addURLs(expandedURLs)
        }
    }
    
    private func processURLs(_ urls: [URL], with vm: ImageToolsViewModel) {
        Task { @MainActor in
            let expandedURLs = urls.flatMap { IngestionCoordinator.expandToSupportedImageURLs(from: $0) }
            vm.addURLs(expandedURLs)
        }
    }
}

@main
struct ImageToolsApp: App {
    @StateObject private var vm = ImageToolsViewModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Window("Image Tools", id: "main") {
            MainView()
                .background(.clear)
                .onAppear { AppDelegate.sharedViewModel = vm }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .environmentObject(vm)
        .handlesExternalEvents(matching: []) // can put [main]
    }
}
