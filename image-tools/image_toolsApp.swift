import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    static var sharedViewModel: ImageToolsViewModel?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let vm = AppDelegate.sharedViewModel else { return }
        let expandedURLs = urls.flatMap { IngestionCoordinator.expandToSupportedImageURLs(from: $0) }
        vm.addURLs(expandedURLs)
    }
}

@main
struct ImageToolsApp: App {
    @StateObject private var vm = ImageToolsViewModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .background(.clear)
                .onAppear { AppDelegate.sharedViewModel = vm }
                .handlesExternalEvents(preferring: ["main"], allowing: ["*"])
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .environmentObject(vm)
        .handlesExternalEvents(matching: ["main"])
    }
}
