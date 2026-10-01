import SwiftUI

/// Amazon's sign-in page in a sheet of its own: the web view, a title, and a
/// way out. The one sheet every Amazon connection opens — Audible's and
/// Kindle's, from their screens and from onboarding.
struct AmazonSignInSheet: View {
    let login: AmazonLogin
    /// Called once with the authorization code the landing URL carried.
    let onCode: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            AmazonSignInWebView(login: login, onCode: onCode)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Connexion Amazon")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        ToolbarIconButton(title: "Annuler", systemImage: "xmark", role: .cancel, action: onCancel)
                    }
                }
        }
    }
}
