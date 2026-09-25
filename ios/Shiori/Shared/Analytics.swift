import FirebaseAnalytics
import Foundation

/// The milestones of the activation funnel, as an enum rather than free-form
/// strings at the call site: a misspelled event name is invisible in GA4 and
/// definitive, since a property never forgets a name it was once sent.
///
/// GA4 reports `first_open`, `session_start` and the retention cohorts on its
/// own, so only what the product means is declared here. The funnel then reads
/// `first_open` → `onboarding_completed` → `book_added` → `library_stocked` →
/// `purchase_completed` without any further code.
enum AnalyticsEvent {
    /// The wizard appeared: the entrance of the funnel.
    case onboardingStarted
    case onboardingCompleted
    /// A book entered the library — the activation metric.
    case bookAdded(source: BookSource)
    case scanStarted
    case scanSucceeded
    case scanNoResult
    /// The analysis did not come back at all: a timeout or a model error, not a
    /// cover nobody recognized. What the retry offer exists for.
    case scanFailed
    /// A scan was refused for want of allowance: where the wall is met.
    case scanBlockedByQuota
    /// The library crossed the bar of a shelf worth opening the app for. Fired
    /// once per install.
    case libraryStocked(books: Int)
    /// A book was rated — the signal the reading suggestions will be built on.
    case bookRated(stars: Int)
    /// A saga was catalogued for the first time, which is what a scan pays for
    /// on behalf of every later reader of that saga.
    case seriesCatalogued
    case paywallShown(trigger: String)
    case purchaseCompleted(plan: String)

    /// How a book got into the library. `scan` costs a credit, the other two
    /// cost nothing — telling them apart is what makes the quota readable
    /// against real usage.
    enum BookSource: String {
        case scan
        case manual
        /// Added from a series catalogue, without a photo or an AI call.
        case series
        /// Added from Découvrir, built from what the web announced.
        case discover
        /// Added from an author's page: a saga's first volume, or a book of theirs.
        case author
    }
}

/// Called once at launch, right after Firebase is configured. Collection has to be
/// settled at the SDK level and not only at ours: Firebase reports `first_open`,
/// `session_start` and `user_engagement` on its own, so muting `track` alone would
/// still have counted every simulator run and every CI scenario as a real install
/// in the property the numbers are read from.
///
/// Set on every launch rather than once: the SDK remembers the flag across
/// launches, and the same install must follow the arguments it was started with.
func startAnalytics() {
    Analytics.setAnalyticsCollectionEnabled(analyticsEnabled)
}

/// Records a milestone. Deliberately free of any return value or error: analytics
/// must never be something a screen has to handle.
func track(_ event: AnalyticsEvent) {
    guard analyticsEnabled else { return }
    Analytics.logEvent(event.name, parameters: event.parameters)
}

/// Fired at most once per install, whatever the caller does. The flag is the
/// event's own name, so a new threshold event needs nothing else.
func trackOnce(_ event: AnalyticsEvent) {
    let key = "analytics.once.\(event.name)"
    guard !UserDefaults.standard.bool(forKey: key) else { return }
    UserDefaults.standard.set(true, forKey: key)
    track(event)
}

/// Collection is off in Debug for the same reason Sentry is: a simulator run must
/// not land in the property the real numbers are read from. `-analyticsDebug`
/// opens it back up for verification, alongside Firebase's own `-FIRDebugEnabled`
/// which routes the events to the DebugView.
///
/// A UI test run is muted in every configuration: the end-to-end scenario walks
/// the whole funnel, and counting it would invent an activated user per CI run.
private var analyticsEnabled: Bool {
    let arguments = ProcessInfo.processInfo.arguments
    if arguments.contains("-uiTestAccount") { return false }
    #if DEBUG
    return arguments.contains("-analyticsDebug")
    #else
    return true
    #endif
}

extension AnalyticsEvent {
    /// snake_case, the convention every GA4 report expects.
    var name: String {
        switch self {
        case .onboardingStarted: "onboarding_started"
        case .onboardingCompleted: "onboarding_completed"
        case .bookAdded: "book_added"
        case .scanStarted: "scan_started"
        case .scanSucceeded: "scan_succeeded"
        case .scanNoResult: "scan_no_result"
        case .scanFailed: "scan_failed"
        case .scanBlockedByQuota: "scan_blocked_quota"
        case .libraryStocked: "library_stocked"
        case .bookRated: "book_rated"
        case .seriesCatalogued: "series_catalogued"
        case .paywallShown: "paywall_shown"
        case .purchaseCompleted: "purchase_completed"
        }
    }

    var parameters: [String: Any]? {
        switch self {
        case let .bookAdded(source): ["source": source.rawValue]
        case let .libraryStocked(books): ["books": books]
        case let .bookRated(stars): ["stars": stars]
        case let .paywallShown(trigger): ["trigger": trigger]
        case let .purchaseCompleted(plan): ["plan": plan]
        default: nil
        }
    }
}
