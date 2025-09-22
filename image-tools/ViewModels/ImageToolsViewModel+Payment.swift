import Foundation
import AppKit
import SwiftUI

extension ImageToolsViewModel {
    // Public paywall state
    func paywallContinueFree() {
        isPaywallPresented = false
        // Allow one immediate apply to proceed after dismissing the paywall
        shouldBypassPaywallOnce = true
        applyPipelineAsync()
    }

    func paywallPurchaseLifetime() {
        // StoreKit integration will replace this later
        isProUnlocked = true
        isPaywallPresented = false
    }

    enum SupportLink: String { case recover, privacy, openSource, help }
    func openSupportURL(_ link: SupportLink) {
        let urlString: String
        switch link {
        case .recover: urlString = "https://imagetools.app/recover"
        case .privacy: urlString = "https://imagetools.app/privacy"
        case .openSource: urlString = "https://github.com/rpgraffi/image-tools"
        case .help: urlString = "https://imagetools.app/help"
        }
        if let url = URL(string: urlString) { NSWorkspace.shared.open(url) }
    }
}


