import SwiftUI

/// The reader's avatar as a toolbar button, ringed as the TV app rings it: a
/// rim of the same glass as the buttons beside it, at their size, so the face
/// stands off the page in light and dark alike.
struct AccountAvatarButton: View {
    let avatar: AccountAvatar
    let firstName: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            AccountAvatarView(avatar: avatar, firstName: firstName, size: 38)
                .padding(3)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Réglages")
    }
}

#Preview {
    NavigationStack {
        List { Text(verbatim: "Shiori") }
            .navigationTitle("Accueil")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {} label: { Label("Rechercher", systemImage: "magnifyingglass") }
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItem(placement: .topBarTrailing) {
                    AccountAvatarButton(avatar: .hero(.carl), firstName: "Thibaut") {}
                }
                .sharedBackgroundVisibility(.hidden)
            }
    }
}
