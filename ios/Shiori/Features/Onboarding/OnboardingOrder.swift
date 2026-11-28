import Foundation

/// The order a new reader goes through: their first name and face, then the free month,
/// then their libraries, then the app. The free month comes before the libraries because
/// there is no free plan: a reader who declines it has nothing to import into, and a reader
/// who takes it imports with the trial already running, so the paid passes serve them.
/// Pure, so the order is tested without a view.
enum OnboardingOrder {
    enum Step: Equatable {
        case firstName
        /// « Votre mois offert », until the server holds a subscription for the account.
        case trial
        case libraries
    }

    /// Where the wizard goes once the profile exists: the libraries straight away for an
    /// account already subscribed (a purchase restored from another device), the free
    /// month otherwise. An unknown plan is not a subscription: the wall waits for it.
    static func afterProfile(isPremium: Bool?) -> Step {
        isPremium == true ? .libraries : .trial
    }

    /// Where a reader whose onboarding the server already holds opens the app.
    enum Ready: Equatable {
        /// No subscription: the wall stands in for the app, libraries or not.
        case wall
        /// Subscribed after leaving the wizard on the wall: the library steps they have
        /// not seen yet, then the app.
        case libraries
        case app
    }

    static func ready(requiresSubscription: Bool, librariesPending: Bool) -> Ready {
        if requiresSubscription { return .wall }
        return librariesPending ? .libraries : .app
    }
}

/// Whether the account still has the library steps ahead of it: set once the profile
/// exists, cleared when the reader goes into the app. Kept on the device, per account: a
/// reader who leaves the wizard on the free month and subscribes later still meets them.
enum OnboardingLibrariesPending {
    private static func key(_ userID: String) -> String { "onboarding.librariesPending.\(userID)" }

    static func isPending(_ userID: String?) -> Bool {
        guard let userID else { return false }
        return UserDefaults.standard.bool(forKey: key(userID))
    }

    static func set(_ pending: Bool, for userID: String?) {
        guard let userID else { return }
        if pending {
            UserDefaults.standard.set(true, forKey: key(userID))
        } else {
            UserDefaults.standard.removeObject(forKey: key(userID))
        }
    }
}
