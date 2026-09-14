import Foundation
import OSLog
import Sentry

/// What the message is about. Travels as a Sentry tag so the inbox can be
/// filtered on it.
enum FeedbackKind: String {
    case bug
    case idea
}

/// Sends a message written by the user to the Sentry feedback inbox.
///
/// Only the message travels: no name, no email. `AuthSession` reports the uid
/// and nothing else, and that uid is already on the scope, which is enough to
/// reach the account behind the message.
func sendFeedback(kind: FeedbackKind, message: String) {
    #if DEBUG
    // Sentry never starts in a Debug build, so `capture` below would silently
    // drop the message. Logging it keeps the screen testable on the simulator.
    // `notice` rather than `debug`: debug entries are not kept in the log store,
    // so they cannot be read back after the fact with `log show`.
    log.notice("feedback (\(kind.rawValue, privacy: .public)): \(message, privacy: .public)")
    #endif

    // The feedback envelope carries no tags of its own; the hub captures it with
    // the current scope, so the tag has to sit there for the length of the call.
    SentrySDK.configureScope { $0.setTag(value: kind.rawValue, key: feedbackKindTag) }
    SentrySDK.capture(feedback: SentryFeedback(
        message: message,
        name: nil,
        email: nil,
        source: .custom
    ))
    SentrySDK.configureScope { $0.removeTag(key: feedbackKindTag) }
}

private let feedbackKindTag = "feedback.kind"

#if DEBUG
private let log = Logger(subsystem: "com.polyforms.shiori.app", category: "feedback")
#endif
