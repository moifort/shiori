import FirebaseCore
import SwiftUI

/// Top-level gate: shows the blocking update screen when the backend no longer
/// supports this build; otherwise `LoginView` when no Firebase user is signed in;
/// once signed in, reads the onboarding state and shows the wizard until it is
/// completed, otherwise the main TabView (`ContentView`).
///
/// Invitation links are caught here rather than deeper in, because the link may
/// arrive before there is anywhere to show it: a reader who taps an invitation
/// without an account lands on the login screen, and the code has to survive
/// until they are signed in and past onboarding. This view outlives both.
struct AuthRoot: View {
    @State private var session = AuthSession()
    @State private var gate = OnboardingGate()
    @State private var supportGate = AppSupportGate()
    /// App-scoped: it listens to `Transaction.updates` for the whole lifetime of
    /// the app, so a renewal landing mid-session is picked up wherever the user is.
    @State private var subscriptions = SubscriptionStore()
    /// An invitation the reader tapped, held until there is a screen to ask on.
    @State private var invitationRequest: InvitationRequest?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if case .updateRequired(let appStoreURL) = supportGate.state {
                UpdateRequiredView(appStoreURL: appStoreURL)
            } else if session.user == nil {
                LoginView()
            } else {
                signedIn
            }
        }
        // Down until the app knows where to open: the sign-in, or the account's
        // own route once the launch request has answered, whatever it said.
        .launchCurtain(until: session.user == nil || gate.state != .loading)
        .environment(session)
        .environment(subscriptions)
        .environment(\.isAdmin, gate.isAdmin)
        .environment(\.accountFirstName, gate.firstName)
        .task { await supportGate.check() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await supportGate.check() } }
        }
        // One request routes the launch and carries the plan along: it needs a
        // signed-in caller, and the plan is the server's answer.
        .task(id: session.user?.uid) {
            if session.user != nil {
                await gate.refresh(subscriptions: subscriptions)
            } else {
                gate.reset()
            }
        }
        // Both shapes of invitation link land here: the universal link, and the
        // shiori:// the web page falls back to.
        .onOpenURL { url in
            if let code = InvitationLink.code(from: url) {
                invitationRequest = InvitationRequest(code: code)
            }
        }
    }

    @ViewBuilder
    private var signedIn: some View {
        switch gate.state {
        case .loading:
            StartupLoadingView()
        case .required:
            OnboardingView(onCompleted: { gate.markCompleted(firstName: $0) })
        case .ready:
            ContentView(invitation: $invitationRequest)
        case .failed(let message):
            ContentUnavailableView {
                Label("Connexion impossible", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                AsyncButton("Réessayer") { await gate.refresh(subscriptions: subscriptions) }
            }
        }
    }
}

#Preview {
    // `AuthSession` reads `Auth.auth()` on init, which traps when Firebase was
    // never configured: the canvas does not run `ShioriApp.init`, so the gate
    // configures it here. With no session in the simulator this lands on the
    // login screen, which is the only state the canvas can reach on its own.
    if FirebaseApp.app() == nil { FirebaseApp.configure() }
    return AuthRoot()
}
