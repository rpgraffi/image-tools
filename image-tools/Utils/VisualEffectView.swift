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

// Keep window configuration centralized for reuse
@MainActor
enum WindowConfigurator {
    private static var didSetInitialSize: Bool = false
    static func configureMainWindow() {
        guard let window = NSApp.windows.first else { return }
        window.title = "Image Tools"
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        // Install a custom trailing accessory with our SwiftUI counter
        
        // --- ADD THIS PART ---
        // Create and assign a toolbar to the window
        let toolbar = NSToolbar(identifier: "MainToolbar")
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar

        installTrailingAccessory(window: window)
        window.center()
    }

    private static func installTrailingAccessory(window: NSWindow) {
        let hosting = NSHostingController(rootView: WindowTitleBar())
        hosting.view.frame.size = NSSize(width: 200, height: 24)

        let accessory = NSTitlebarAccessoryViewController()
        accessory.identifier = NSUserInterfaceItemIdentifier("UsageAccessory")
        accessory.view = hosting.view
        accessory.layoutAttribute = .trailing
        window.addTitlebarAccessoryViewController(accessory)
    }
} 
