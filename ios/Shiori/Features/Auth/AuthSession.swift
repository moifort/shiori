import FirebaseAuth
import Observation
import Sentry

/// Single source of truth for the currently authenticated Firebase user.
/// Lives at app scope; views that need to react to sign-in/out observe `user`.
@MainActor
@Observable
final class AuthSession {
    // Qualified: importing Sentry brings its own `User` into scope.
    private(set) var user: FirebaseAuth.User?
    @ObservationIgnored
    nonisolated(unsafe) private var handle: AuthStateDidChangeListenerHandle?

    init() {
        user = Auth.auth().currentUser
        report(user)
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
                self?.report(user)
            }
        }
    }

    /// Names the account behind a crash report. Only the uid travels: no email,
    /// no display name. It answers "how many people hit this" on an issue, and
    /// points at the documents to look at.
    private func report(_ user: FirebaseAuth.User?) {
        SentrySDK.setUser(user.map { Sentry.User(userId: $0.uid) })
    }

    deinit {
        if let handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }
}
