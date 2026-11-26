import SwiftUI

/// Amazon's sign-in page in a sheet of its own: the web view, a title, and a
/// way out. The one sheet every Amazon connection opens — Audible's and
/// Kindle's, from their screens and from onboarding.
struct AmazonSignInSheet: View {
    let login: AmazonLogin
    /// Called once with the authorization code the landing URL carried.
    let onCode: (String) -> Void
    let onCancel: () -> Void
    /// The library the page signs in to, named in the title so the reader
    /// knows which one Amazon's page is for; Amazon alone when none is given.
    var source: ImportSource?
    /// The store and the step, under the title, during the onboarding.
    var subtitle: String?

    var body: some View {
        NavigationStack {
            AmazonSignInWebView(login: login, onCode: onCode)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(title)
                .modifier(SheetSubtitle(text: subtitle))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        ToolbarIconButton(title: "Annuler", systemImage: "xmark", role: .cancel, action: onCancel)
                    }
                }
        }
    }

    private var title: LocalizedStringResource {
        switch source {
        case .audible: "Connexion Audible"
        case .kindle: "Connexion Kindle"
        case nil: "Connexion Amazon"
        }
    }
}

/// The subtitle when there is one, nothing reserved for it otherwise.
private struct SheetSubtitle: ViewModifier {
    let text: String?

    func body(content: Content) -> some View {
        if let text {
            content.navigationSubtitle(text)
        } else {
            content
        }
    }
}

#Preview {
    AmazonSignInSheet(
        login: AmazonLogin(
            url: "https://www.amazon.fr",
            redirectURL: "https://www.amazon.fr/ap/maplanding",
            cookies: []
        ),
        onCode: { _ in },
        onCancel: {}
    )
}
