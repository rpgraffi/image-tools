import SwiftUI
import AppKit


@MainActor
enum WindowConfigurator {
    static func configureMainWindow() {
        guard let window = NSApp.windows.first else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        
        let toolbar = NSToolbar(identifier: "MainToolbar")
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar
        window.center()
    }
} 
