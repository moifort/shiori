import FirebaseCore
import SwiftUI

/// The wizard shown once, before the library exists. Three steps, not Vinarium's
/// five: there is no cellar to size, so all it collects is a first name — and
/// then it offers to bring an Audible library, a Kindle library or both in,
/// which a reader can skip.
///
/// It is kept as a wizard rather than a single field because of what completing
/// it does — it grants the welcome scans — and because the welcome step is the
/// one place to say what the app is for before asking for anything.
struct OnboardingView: View {
    /// Handed the first name the reader gave, so the app knows it without
    /// asking the server.
    var onCompleted: (String) -> Void

    @Environment(AuthSession.self) private var session
    @State private var step: Step = .welcome
    @State private var firstName = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    /// Which libraries the reader asked to connect.
    @State private var connectsAudible = false
    @State private var connectsKindle = false
    /// The store the reader signs in on, for both, proposed from the device
    /// region.
    @State private var marketplace: AmazonMarketplace = .suggested
    /// The sources still to sign in, in order, and the one Amazon's page is
    /// open for.
    @State private var pendingSources: [ImportSource] = []
    @State private var signingIn: ImportSource?
    /// Amazon's sign-in page, while it is on screen.
    @State private var signIn: AmazonLogin?
    /// Between tapping "Connecter" and Amazon's page, and between the page
    /// closing and the next one — or the app — opening.
    @State private var isConnecting = false
    /// A sign-in that failed, said before moving on to the next source.
    @State private var connectionError: String?

    private enum Step {
        case welcome
        case firstName
        /// After `completeOnboarding`, so the welcome scans are granted even
        /// when the reader abandons the Amazon sign-in halfway.
        case libraries
    }

    var body: some View {
        Group {
            switch step {
            case .welcome:
                WelcomePage(onNext: { withAnimation { step = .firstName } })
            case .firstName:
                FirstNamePage(
                    firstName: $firstName,
                    onNext: { Task { await complete() } },
                    onBack: { withAnimation { step = .welcome } }
                )
            case .libraries:
                LibrariesOfferPage(
                    connectsAudible: $connectsAudible,
                    connectsKindle: $connectsKindle,
                    marketplace: $marketplace,
                    isWorking: isConnecting,
                    onConnect: connectChosenSources,
                    onSkip: enterApp
                )
            }
        }
        // Straight to Amazon's page for each source, and from the last one
        // straight into the app: every library is imported in the background,
        // the dashboard waiting on the passes behind its preparation screen,
        // with no picker in between.
        .sheet(item: $signIn) { login in
            AmazonSignInSheet(login: login, onCode: { code in
                Task { await finishSignIn(code: code) }
            }, onCancel: {
                // A source abandoned is a source skipped: on to the next one.
                signIn = nil
                Task { await connectNextSource() }
            })
        }
        .alert(
            "Connexion impossible",
            isPresented: .init(get: { connectionError != nil }, set: { if !$0 { connectionError = nil } })
        ) {
            Button("OK", role: .cancel) {
                connectionError = nil
                Task { await connectNextSource() }
            }
        } message: {
            Text("\(connectionError ?? "") Vous pourrez réessayer depuis les réglages.")
        }
        .disabled(isSaving)
        .overlay { if isSaving { ProgressView().controlSize(.large) } }
        .alert(
            "Impossible de terminer",
            isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear {
            track(.onboardingStarted)
            // Proposed, not imposed: the field stays editable.
            if firstName.isEmpty, let suggested = session.suggestedFirstName {
                firstName = suggested
            }
        }
    }

    /// Audible first, then Kindle: the order the page lists them in.
    private func connectChosenSources() {
        pendingSources = ImportSource.allCases.filter { source in
            switch source {
            case .audible: connectsAudible
            case .kindle: connectsKindle
            }
        }
        Task { await connectNextSource() }
    }

    /// Opens Amazon's page for the next source, or goes in once none is left.
    /// A source whose page cannot be opened is said, then stepped over.
    private func connectNextSource() async {
        guard !pendingSources.isEmpty else {
            signingIn = nil
            enterApp()
            return
        }
        let source = pendingSources.removeFirst()
        signingIn = source
        isConnecting = true
        defer { isConnecting = false }
        do {
            signIn = switch source {
            case .audible: try await ImportAPI.startSignIn(on: marketplace)
            case .kindle: try await KindleAPI.startSignIn(on: marketplace)
            }
        } catch {
            connectionError = reportError(error)
        }
    }

    /// The code Amazon handed back: the library is linked, its pass starts in
    /// the background, and the next source is opened. A failed link is said,
    /// then stepped over — the reader can connect it again from the settings.
    private func finishSignIn(code: String) async {
        signIn = nil
        guard let source = signingIn else { return }
        isConnecting = true
        do {
            switch source {
            case .audible:
                _ = try await ImportAPI.completeSignIn(authorizationCode: code)
                AudibleBackgroundSync.shared.start()
            case .kindle:
                _ = try await KindleAPI.completeSignIn(authorizationCode: code)
                KindleBackgroundSync.shared.start()
            }
        } catch {
            isConnecting = false
            connectionError = reportError(error)
            return
        }
        isConnecting = false
        await connectNextSource()
    }

    /// Into the app by way of the preparation screen, which the dashboard
    /// draws until the library is ready to be shown.
    private func enterApp() {
        LibraryPreparation.shared.begin()
        onCompleted(firstName.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func complete() async {
        let name = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await OnboardingAPI.completeOnboarding(firstName: name)
            track(.onboardingCompleted)
            withAnimation { step = .libraries }
        } catch {
            // Stays on the step rather than dropping the reader into an empty
            // app: the welcome scans are granted by this call, and letting it
            // fail silently would cost them 50 scans they never learn about.
            errorMessage = reportError(error)
        }
    }
}

#Preview {
    // `AuthSession` reads `Auth.auth()` on init, which traps when Firebase was
    // never configured: the canvas does not run `ShioriApp.init`.
    if FirebaseApp.app() == nil { FirebaseApp.configure() }
    return OnboardingView(onCompleted: { _ in }).environment(AuthSession())
}
