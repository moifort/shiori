import FirebaseCore
import SwiftUI

/// Top-level gate: shows the blocking update screen when the backend no longer
/// supports this build; otherwise `LoginScreen` when no Firebase user is signed in;
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
    @State private var preparation = LibraryPreparation.shared
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
            } else if isShowcase {
                signedIn
            } else if session.user == nil {
                LoginScreen()
            } else {
                signedIn
            }
        }
        // One wall from the sign-in to the end of onboarding, so the covers keep
        // drifting while the screens change in front of them.
        .background { if showsCoverWall { CoverWall() } }
        // Down until the app knows where to open: the sign-in, or the account's
        // own route once the launch request has answered, whatever it said.
        .launchCurtain(until: session.user == nil || gate.state != .loading)
        .environment(session)
        .environment(subscriptions)
        .environment(\.isAdmin, gate.isAdmin)
        .environment(\.accountFirstName, gate.firstName)
        .environment(\.accountAvatar, gate.avatar)
        .environment(\.showAccountAvatar, ShowAccountAvatar { gate.showAvatar($0) })
        .task {
            guard !isShowcase else { return }
            await supportGate.check()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, !isShowcase { Task { await supportGate.check() } }
        }
        // One request routes the launch and carries the plan along: it needs a
        // signed-in caller, and the plan is the server's answer.
        .task(id: session.user?.uid) {
            if session.user != nil || isShowcase {
                await gate.refresh(subscriptions: subscriptions, expectsNewReader: session.isFirstAuthorization)
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

    /// The App Store captures: signed in as the showcase reader, without Apple.
    private var isShowcase: Bool {
        #if DEBUG
        Showcase.isOn
        #else
        false
        #endif
    }

    /// Everywhere a reader is still getting in, up to the end of the library's
    /// preparation, and nowhere once they are.
    private var showsCoverWall: Bool {
        if case .updateRequired = supportGate.state { return false }
        guard !isShowcase else { return false }
        if session.user == nil { return true }
        return gate.state == .loading || gate.state == .required || preparation.isActive
    }

    /// A new reader goes straight to the wizard, from the very first frame
    /// after signing in: the gate only hears of them once its request starts.
    private var route: OnboardingGate.State {
        gate.state == .loading && session.isFirstAuthorization ? .required : gate.state
    }

    @ViewBuilder
    private var signedIn: some View {
        switch route {
        case .loading:
            ZStack {
                CoverVeil(covering: true)
                OpeningProgress(label: "Préparation de votre bibliothèque…")
            }
            .environment(\.colorScheme, .dark)
        case .required:
            OnboardingScreen(onCompleted: { gate.markCompleted(firstName: $0, avatar: $1) })
        case .ready:
            ZStack {
                // Kept running out of sight: the checklist's last line is its
                // dashboard loading.
                ContentView(invitation: $invitationRequest)
                    .opacity(preparation.isActive ? 0 : 1)
                if preparation.isActive {
                    ZStack {
                        CoverVeil(covering: true)
                        LibraryPreparationView()
                    }
                    .environment(\.colorScheme, .dark)
                    .transition(.opacity)
                }
            }
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
