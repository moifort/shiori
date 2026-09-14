import Foundation

/// The two subscriptions sold, as declared in App Store Connect and mirrored in
/// `ios/Shiori/Shiori.storekit` for local testing. The identifiers must match all
/// three places exactly — a typo simply makes the product fail to load, silently.
enum SubscriptionProducts {
    static let yearly = "com.polyforms.shiori.app.premium.yearly"
    static let monthly = "com.polyforms.shiori.app.premium.monthly"

    /// Yearly first: it is the offer the sheet puts forward.
    static let all = [yearly, monthly]
}
