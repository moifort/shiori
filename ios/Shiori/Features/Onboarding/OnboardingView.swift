import SwiftUI

/// The wizard shown once, before the library exists. Three steps, not Vinarium's
/// five: there is no cellar to size, so all it collects is a first name — and
/// then it offers to bring an Audible library in, which a reader can skip.
///
/// It is kept as a wizard rather than a single field because of what completing
/// it does — it grants the welcome scans — and because the welcome step is the
/// one place to say what the app is for before asking for anything.
struct OnboardingView: View {
    /// Handed the first name the reader gave, so the app knows it without
    /// asking the server.
    var onCompleted: (String) -> Void

    @State private var step: Step = .welcome
    @State private var firstName = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    /// Amazon's sign-in page, while it is on screen.
    @State private var audibleSignIn: AudibleLogin?
    /// The store the reader signs in on, proposed from the device region.
    @State private var audibleMarketplace: AudibleMarketplace = .suggested
    /// Between tapping "Importer" and Amazon's page, and between the page
    /// closing and the app opening.
    @State private var isConnectingAudible = false

    private enum Step {
        case welcome
        case firstName
        /// After `completeOnboarding`, so the welcome scans are granted even
        /// when the reader abandons the Amazon sign-in halfway.
        case audible
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
            case .audible:
                AudibleOfferPage(
                    marketplace: $audibleMarketplace,
                    isWorking: isConnectingAudible,
                    onConnect: { Task { await startAudibleSignIn() } },
                    onSkip: enterApp
                )
            }
        }
        // Straight to Amazon's page, and from it straight into the app: the
        // whole library is imported in the background, the dashboard waiting
        // on the pass behind its preparation screen, with no picker in between.
        .sheet(item: $audibleSignIn) { login in
            NavigationStack {
                AmazonSignInWebView(login: login) { code in
                    Task { await finishAudibleSignIn(code: code) }
                }
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Connexion Amazon")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        ToolbarIconButton(title: "Annuler", systemImage: "xmark", role: .cancel) {
                            audibleSignIn = nil
                        }
                    }
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
        .onAppear { track(.onboardingStarted) }
    }

    private func startAudibleSignIn() async {
        isConnectingAudible = true
        defer { isConnectingAudible = false }
        do {
            audibleSignIn = try await ImportAPI.startSignIn(on: audibleMarketplace)
        } catch {
            errorMessage = reportError(error)
        }
    }

    /// The code Amazon handed back: the account is linked, the pass starts in
    /// the background, and the reader goes in. A failed link leaves them on the
    /// offer, free to try again or skip.
    private func finishAudibleSignIn(code: String) async {
        audibleSignIn = nil
        isConnectingAudible = true
        defer { isConnectingAudible = false }
        do {
            _ = try await ImportAPI.completeSignIn(authorizationCode: code)
            AudibleBackgroundSync.shared.start()
            enterApp()
        } catch {
            errorMessage = reportError(error)
        }
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
            withAnimation { step = .audible }
        } catch {
            // Stays on the step rather than dropping the reader into an empty
            // app: the welcome scans are granted by this call, and letting it
            // fail silently would cost them 50 scans they never learn about.
            errorMessage = reportError(error)
        }
    }
}

#Preview {
    OnboardingView(onCompleted: { _ in })
}
