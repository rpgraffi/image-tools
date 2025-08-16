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
enum WindowConfigurator {
    static func configureMainWindow() {
        guard let window = NSApp.windows.first else { return }
        window.title = "Image Tools"
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        // Install a custom trailing accessory with our SwiftUI counter
        installTrailingAccessory(window: window)
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