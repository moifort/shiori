import FirebaseCore
import SwiftUI

/// Top-level gate: shows the blocking update screen when the backend no longer
/// supports this build; otherwise `LoginView` when no Firebase user is signed in;
/// once signed in, reads the onboarding state and shows the wizard until it is
/// completed, otherwise the main TabView (`ContentView`).
///
/// There is no deep-link handling here. Vinarium catches household invitation
/// links at this point; Shiori shares nothing yet, so there is no link to catch.
struct AuthRoot: View {
    @State private var session = AuthSession()
    @State private var gate = OnboardingGate()
    @State private var supportGate = AppSupportGate()
    /// App-scoped: it listens to `Transaction.updates` for the whole lifetime of
    /// the app, so a renewal landing mid-session is picked up wherever the user is.
    @State private var subscriptions = SubscriptionStore()
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
        .environment(session)
        .environment(subscriptions)
        .environment(\.isAdmin, gate.isAdmin)
        .task { await supportGate.check() }
        .task(id: session.user?.uid) {
            // The plan is the server's answer, and it needs a signed-in caller.
            if session.user != nil { await subscriptions.refresh() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await supportGate.check() } }
        }
        .task(id: session.user?.uid) {
            if session.user != nil {
                await gate.refresh()
            } else {
                gate.reset()
            }
        }
    }

    @ViewBuilder
    private var signedIn: some View {
        switch gate.state {
        case .loading:
            StartupLoadingView()
        case .required:
            OnboardingView(onCompleted: { gate.markCompleted() })
        case .ready:
            ContentView()
        case .failed(let message):
            ContentUnavailableView {
                Label("Connexion impossible", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                AsyncButton("Réessayer") { await gate.refresh() }
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
