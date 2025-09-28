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

        // Set a default starting size once per app run
        if !didSetInitialSize {
            let defaultSize = NSSize(width: 850, height: 600)
            window.setContentSize(defaultSize)
            window.center()
            didSetInitialSize = true
        }
    }

    private static func installTrailingAccessory(window: NSWindow) {
        let hosting = NSHostingController(rootView: WindowTitleBar(vm: ImageToolsViewModelAccessor.shared()))
        hosting.view.frame.size = NSSize(width: 160, height: 24)

        let accessory = NSTitlebarAccessoryViewController()
        accessory.identifier = NSUserInterfaceItemIdentifier("UsageAccessory")
        accessory.view = hosting.view
        accessory.layoutAttribute = .trailing
        window.addTitlebarAccessoryViewController(accessory)
    }
} 

// Provide access to the singleton VM used in the SwiftUI App scene
@MainActor
enum ImageToolsViewModelAccessor {
    private static weak var currentVM: ImageToolsViewModel?
    static func set(_ vm: ImageToolsViewModel) { currentVM = vm }
    static func shared() -> ImageToolsViewModel {
        if let vm = currentVM { return vm }
        // Fallback (should not happen): create a new instance
        let vm = ImageToolsViewModel()
        currentVM = vm
        return vm
    }
}
