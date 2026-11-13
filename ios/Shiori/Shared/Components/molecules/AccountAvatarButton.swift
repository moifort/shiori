import SwiftUI

/// The reader's avatar as a toolbar button, ringed as the TV app rings it: a
/// rim of the same glass as the buttons beside it, at their size, so the face
/// stands off the page in light and dark alike. The glass is faintly tinted
/// with the avatar's own colour, as an aura.
struct AccountAvatarButton: View {
    let avatar: AccountAvatar
    let firstName: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            AccountAvatarView(avatar: avatar, firstName: firstName, size: 38)
                .padding(3)
                .glassEffect(.regular.tint(avatar.aura?.opacity(0.2)).interactive(), in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Réglages")
    }
}

/// The reader's avatar, opening the settings: the last button on the right of
/// every tab's root bar, as on the home, so the account is one tap away
/// wherever the reader is. Pushed pages keep their own bar.
struct AccountSettingsButton: View {
    @Environment(\.accountAvatar) private var avatar
    @Environment(\.accountFirstName) private var firstName
    @State private var showsSettings = false

    var body: some View {
        AccountAvatarButton(avatar: avatar, firstName: firstName) {
            showsSettings = true
        }
        .sheet(isPresented: $showsSettings) {
            SettingsHomeScreen()
        }
    }
}

extension View {
    /// The reader's avatar at the right end of the bar, for a page whose bar
    /// holds nothing else on that side.
    func accountSettingsButton() -> some View {
        toolbar {
            ToolbarItem(placement: .topBarTrailing) { AccountSettingsButton() }
                .sharedBackgroundVisibility(.hidden)
        }
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
