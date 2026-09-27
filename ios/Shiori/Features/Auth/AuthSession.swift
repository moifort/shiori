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
    /// The given name Apple handed over at sign-in. Apple sends the name only
    /// on the very first authorization, so it is kept the moment it arrives.
    private var appleGivenName: String?

    /// The first name to propose in onboarding: Apple's given name when this
    /// sign-in carried one, else the one Firebase kept in the display name
    /// from that first authorization — a relaunch between sign-in and
    /// onboarding loses the former, never the latter.
    var suggestedFirstName: String? {
        if let appleGivenName { return appleGivenName }
        guard let displayName = user?.displayName, !displayName.isEmpty else { return nil }
        let givenName = (try? PersonNameComponents(displayName, strategy: .name))?.givenName
        return givenName?.isEmpty == false ? givenName : nil
    }

    init() {
        user = Auth.auth().currentUser
        report(user)
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self else { return }
                // However the session ended — the sign-out button, the account
                // deleted, or a dead session dropped by the API client — the
                // next reader starts clean.
                if self.user != nil, user == nil { self.forgetAccount() }
                self.user = user
                self.report(user)
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

    /// Called by the sign-in screen with the name Apple returned, if any.
    func rememberAppleName(_ fullName: PersonNameComponents?) {
        let givenName = fullName?.givenName?.trimmingCharacters(in: .whitespacesAndNewlines)
        appleGivenName = givenName?.isEmpty == false ? givenName : nil
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    /// Whoever signs in next must not open on this account's library, nor be
    /// handed the page the last reader shared.
    private func forgetAccount() {
        appleGivenName = nil
        SnapshotCaches.clear()
        CoverImages.clear()
        SharedIntake.clear()
    }

    /// Signs out when Firebase no longer knows the signed-in account: deleted,
    /// or disabled. The ID token outlives the account by up to an hour, so a
    /// deletion whose answer never reached the phone would otherwise leave it
    /// on a session every request is refused for. Returns whether it did.
    @discardableResult
    nonisolated static func dropSessionIfAccountIsGone() async -> Bool {
        guard let user = Auth.auth().currentUser else { return false }
        do {
            try await user.reload()
            return false
        } catch {
            let nsError = error as NSError
            guard nsError.domain == AuthErrorDomain,
                  let code = AuthErrorCode(rawValue: nsError.code),
                  [.userNotFound, .userDisabled, .userTokenExpired, .invalidUserToken].contains(code)
            else { return false }
            await MainActor.run { _ = try? Auth.auth().signOut() }
            return true
        }
    }
}
