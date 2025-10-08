import SwiftUI
import AppKit

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.material = .menu
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) { }
}

@MainActor
enum WindowConfigurator {
    static func configureMainWindow() {
        guard let window = NSApp.windows.first else { return }
        window.title = "Image Tools"
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        
        let toolbar = NSToolbar(identifier: "MainToolbar")
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar

        installTrailingAccessory(window: window)
        window.center()
    }

    private static func installTrailingAccessory(window: NSWindow) {
        let accessoryID = NSUserInterfaceItemIdentifier("UsageAccessory")
        
        guard !window.titlebarAccessoryViewControllers.contains(where: { $0.identifier == accessoryID }) else {
            return
        }
        
        let hosting = NSHostingController(rootView: WindowTitleBar())
        hosting.view.frame.size = NSSize(width: 200, height: 24)

        let accessory = NSTitlebarAccessoryViewController()
        accessory.identifier = accessoryID
        accessory.view = hosting.view
        accessory.layoutAttribute = .trailing
        window.addTitlebarAccessoryViewController(accessory)
    }
} 
