import Foundation
import StoreKit

/// Service for managing app rating requests
struct RatingService {
    /// Request a review from the user
    /// - Note: Apple limits this to 3 prompts per 365-day period per device
    /// - The system may or may not show the prompt based on internal policies
    static func requestReview() {
        SKStoreReviewController.requestReview()
    }
    
    /// Open the App Store page for manual review
    /// - Parameter appID: The App Store ID of your app
    static func openAppStoreReview(appID: String) {
        if let url = URL(string: "https://apps.apple.com/app/id\(appID)?action=write-review") {
            NSWorkspace.shared.open(url)
        }
    }
}

