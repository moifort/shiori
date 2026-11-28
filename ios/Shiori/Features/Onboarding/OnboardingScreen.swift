import FirebaseCore
import SwiftUI

/// The wizard shown once, before the library exists. Two steps, not Vinarium's
/// five: there is no cellar to size, so all it collects is a first name and an
/// avatar — and then it offers to bring the reader's Audible, Kindle and
/// Goodreads libraries in, which a reader can skip. Each library ticked gets a
/// step of its own, which says what it is for before Amazon's page opens. Saying what the app is for is the sign-in screen's
/// job, just before.
struct OnboardingScreen: View {
    /// Handed the first name and the avatar the reader gave, so the app knows
    /// them without asking the server.
    var onCompleted: (String, AccountAvatar) -> Void
    var client: OnboardingClient = .live

    /// Straight to the library steps: a reader who left the wizard on the free month and
    /// subscribed later, whose profile the server already holds.
    var startsAtLibraries = false

    @Environment(AuthSession.self) private var session
    @Environment(SubscriptionStore.self) private var subscriptions
    @State private var step: OnboardingOrder.Step = .firstName
    @State private var firstName = ""
    /// Their initials on a colour drawn at random, which the reader keeps or
    /// changes: iOS hands the iCloud photo to no app, and bare slate looks like
    /// an account nobody set up.
    @State private var avatar: AccountAvatar = .tinted(AvatarColor.allCases.randomElement() ?? .blue)
    @State private var isSaving = false
    @State private var errorMessage: String?
    /// Which libraries the reader asked to connect.
    @State private var connectsAudible = false
    @State private var connectsKindle = false
    @State private var importsGoodreads = false
    /// The Goodreads import on screen, after the Amazon sign-ins.
    @State private var goodreadsShown = false
    /// Whether the reader started a Goodreads import, which the preparation
    /// screen goes on to show.
    @State private var startedGoodreads = false
    /// The store the reader signs in on, for both, proposed from the device
    /// region.
    @State private var marketplace: AmazonMarketplace = .suggested
    /// One step per library the reader ticked, each said before its sign-in;
    /// none while the libraries page is on screen.
    @State private var steps: OnboardingLibrarySteps?
    /// The Amazon library whose page is open.
    @State private var signingIn: ImportSource?
    /// The sources linked, which the preparation screen goes on to wait for.
    @State private var linkedSources: [ImportSource] = []
    /// Amazon's sign-in page, while it is on screen.
    @State private var signIn: AmazonLogin?
    /// Between tapping "Connecter" and Amazon's page, and between the page
    /// closing and the confirmation.
    @State private var isConnecting = false

    var body: some View {
        Group {
            switch step {
            case .firstName:
                FirstNamePage(
                    firstName: $firstName,
                    avatar: $avatar,
                    onNext: { Task { await complete() } }
                )
            case .trial:
                // Buying through it syncs the purchase with the server before the plan
                // flips, so the library imports that follow run with the trial active.
                SubscriptionWallScreen()
            case .libraries:
                if let steps, let library = steps.current {
                    LibraryStepPage(
                        library: library,
                        number: steps.number,
                        count: steps.count,
                        phase: steps.phase,
                        next: steps.next,
                        isWorking: isConnecting,
                        onPrimary: { primaryAction(on: library) },
                        onSecondary: moveOn
                    )
                    .id("\(library.rawValue)-\(steps.phase)")
                    .transition(.opacity)
                } else {
                    LibrariesOfferPage(
                        connectsAudible: $connectsAudible,
                        connectsKindle: $connectsKindle,
                        importsGoodreads: $importsGoodreads,
                        marketplace: $marketplace,
                        isWorking: isConnecting,
                        onConnect: beginSteps,
                        onSkip: enterApp
                    )
                }
            }
        }
        .background { CoverVeil(covering: true) }
        .environment(\.colorScheme, .dark)
        // Amazon's page, named after the library it is for: the step said
        // what it brings before it opened. Closing it goes back to that step.
        .sheet(item: $signIn) { login in
            AmazonSignInSheet(
                login: login,
                onCode: { code in Task { await finishSignIn(code: code) } },
                onCancel: { signIn = nil },
                source: signingIn,
                subtitle: steps.map {
                    String(localized: "sur \(marketplace.amazonLabel) · étape \($0.number) sur \($0.count)")
                }
            )
        }
        // The export file: the import starts in the background, and the step
        // confirms it.
        .fullScreenCover(isPresented: $goodreadsShown) {
            GoodreadsImportScreen(mode: .onboarding) { started in
                goodreadsShown = false
                if started {
                    startedGoodreads = true
                    withAnimation { steps?.connected() }
                }
            }
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
        // The free month taken, or a purchase restored: on to the libraries.
        .onChange(of: subscriptions.isPremium) { _, isPremium in
            if step == .trial, isPremium == true { withAnimation { step = .libraries } }
        }
        .onAppear {
            if startsAtLibraries {
                step = .libraries
                return
            }
            track(.onboardingStarted)
            // Proposed, not imposed: the field stays editable.
            if firstName.isEmpty, let suggested = session.suggestedFirstName {
                firstName = suggested
            }
        }
    }

    /// One step per library ticked, Audible, then Kindle, then Goodreads.
    private func beginSteps() {
        var chosen: Set<OnboardingLibrary> = []
        if connectsAudible { chosen.insert(.audible) }
        if connectsKindle { chosen.insert(.kindle) }
        if importsGoodreads { chosen.insert(.goodreads) }
        let steps = OnboardingLibrarySteps(chosen: chosen)
        guard !steps.isFinished else { return enterApp() }
        withAnimation { self.steps = steps }
    }

    /// Connect from the step's page or after a failure, go on once connected.
    private func primaryAction(on library: OnboardingLibrary) {
        switch steps?.phase {
        case .connected: moveOn()
        case .intro, .failed, nil: connect(library)
        }
    }

    /// Amazon's page for an Amazon library, the export screen for Goodreads.
    private func connect(_ library: OnboardingLibrary) {
        guard let source = library.amazonSource else {
            goodreadsShown = true
            return
        }
        Task {
            signingIn = source
            isConnecting = true
            defer { isConnecting = false }
            do {
                signIn = try await client.startSignIn(source, marketplace)
            } catch {
                _ = reportError(error)
                withAnimation { steps?.failed() }
            }
        }
    }

    /// The code Amazon handed back: the library is linked and its pass starts
    /// in the background, then the step confirms it. A failed link is said on
    /// the step, which offers to try again or move on.
    private func finishSignIn(code: String) async {
        signIn = nil
        guard let source = signingIn else { return }
        isConnecting = true
        defer { isConnecting = false }
        do {
            try await client.completeSignIn(source, code)
            linkedSources.append(source)
            withAnimation { steps?.connected() }
        } catch {
            _ = reportError(error)
            withAnimation { steps?.failed() }
        }
    }

    /// The next library's step, or the app once none is left.
    private func moveOn() {
        withAnimation { steps?.advance() }
        if steps?.isFinished == true { enterApp() }
    }

    /// Into the app by way of the preparation screen, drawn until the library
    /// is ready to be shown.
    private func enterApp() {
        OnboardingLibrariesPending.set(false, for: session.user?.uid)
        client.beginPreparation(linkedSources, startedGoodreads)
        onCompleted(firstName.trimmingCharacters(in: .whitespacesAndNewlines), avatar)
    }

    /// After the profile exists, which the avatar hangs off. A failure here
    /// costs the reader nothing they cannot redo from the profile settings, so
    /// it is reported and the wizard moves on with the initials.
    private func keepAvatar() async {
        guard avatar != .initials else { return }
        do {
            avatar = try await client.changeAvatar(avatar)
        } catch {
            _ = reportError(error)
            avatar = .initials
        }
    }

    private func complete() async {
        let name = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await client.complete(name)
            track(.onboardingCompleted)
            await keepAvatar()
            OnboardingLibrariesPending.set(true, for: session.user?.uid)
            withAnimation { step = OnboardingOrder.afterProfile(isPremium: subscriptions.isPremium) }
        } catch {
            // Stays on the step rather than dropping the reader into an empty
            // app: this call saves the profile, and without it the app has no
            // name to address the reader by.
            errorMessage = reportError(error)
        }
    }
}

#Preview {
    // `AuthSession` reads `Auth.auth()` on init, which traps when Firebase was
    // never configured: the canvas does not run `ShioriApp.init`.
    if FirebaseApp.app() == nil { FirebaseApp.configure() }
    return OnboardingScreen(onCompleted: { _, _ in }, client: .preview)
        .environment(AuthSession())
        .environment(SubscriptionStore())
}
