import AuthenticationServices
import FirebaseAuth
import FirebaseCore
import SwiftUI

struct LoginScreen: View {
    @Environment(AuthSession.self) private var session
    @State private var nonce: String = ""
    @State private var error: String?
    @State private var isSigningIn = false

    var body: some View {
        LoginPage(isSigningIn: isSigningIn, error: error) {
            SignInWithAppleButton(.signIn) { request in
                // On the tap itself: Apple's sheet takes a moment to rise, and
                // the wait goes on after it closes.
                error = nil
                isSigningIn = true
                let raw = AppleNonce.random()
                nonce = raw
                request.requestedScopes = [.fullName, .email]
                request.nonce = AppleNonce.sha256(raw)
            } onCompletion: { result in
                Task { await handle(result) }
            }
            .signInWithAppleButtonStyle(.white)
        }
    }

    private func handle(_ result: Result<ASAuthorization, Error>) async {
        defer { isSigningIn = false }
        do {
            let auth = try result.get()
            guard
                let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let token = String(data: tokenData, encoding: .utf8)
            else {
                error = String(localized: "Apple n'a pas renvoyé de jeton.")
                return
            }
            let oauth = OAuthProvider.appleCredential(
                withIDToken: token,
                rawNonce: nonce,
                fullName: credential.fullName
            )
            // Before signing in: the session flips to signed-in the moment
            // Firebase answers, and onboarding reads the name on appearing.
            session.rememberAppleName(credential.fullName)
            _ = try await Auth.auth().signIn(with: oauth)
        } catch ASAuthorizationError.canceled {
            // The reader closed Apple's sheet: nothing went wrong.
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }
}

/// What the sign-in shows over the cover wall. The button stays in the
/// hierarchy while signing in, only hidden: it carries Apple's answer.
struct LoginPage<SignInButton: View>: View {
    var isSigningIn: Bool
    var error: String?
    @ViewBuilder var signInButton: SignInButton

    var body: some View {
        ZStack {
            CoverVeil(covering: isSigningIn)
            if isSigningIn {
                OpeningProgress(label: "Connexion en cours…")
                    .transition(.opacity)
            }
            VStack(spacing: 0) {
                Spacer()
                Text("Tous vos livres,\nau même endroit")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text("Une photo de la couverture suffit.")
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
                signInButton
                    .frame(height: 52)
                    .clipShape(.capsule)
                    .padding(.top, 32)
                if let error {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.top, 12)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .opacity(isSigningIn ? 0 : 1)
            .allowsHitTesting(!isSigningIn)
        }
        .animation(.easeInOut(duration: 0.35), value: isSigningIn)
        .environment(\.colorScheme, .dark)
    }
}

#Preview("Accueil") {
    ZStack {
        CoverWall()
        LoginPage(isSigningIn: false) {
            SignInWithAppleButton(.signIn) { _ in } onCompletion: { _ in }
                .signInWithAppleButtonStyle(.white)
        }
    }
}

#Preview("Connexion") {
    ZStack {
        CoverWall()
        LoginPage(isSigningIn: true) {
            SignInWithAppleButton(.signIn) { _ in } onCompletion: { _ in }
        }
    }
}
