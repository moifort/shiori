import SwiftUI

/// Everything the profile page can ask for.
enum ProfileSettingsAction {
    case changeAvatar(AccountAvatar)
    case signOut
    case deleteAccount
}

/// The account behind the library: its face, who it is, and the two ways out — signing
/// out, which keeps everything, and deleting, which keeps nothing.
struct ProfileSettingsPage: View {
    let firstName: String?
    let avatar: AccountAvatar
    let isSavingAvatar: Bool
    let displayName: String?
    let email: String?
    /// The first eight characters of the account id: enough to name it in a
    /// support message, short enough to read aloud.
    let shortUid: String
    let isDeletingAccount: Bool
    let errorMessage: String?
    let onAction: (ProfileSettingsAction) async -> Void

    @State private var showDeleteConfirmation = false
    @State private var pickingAvatar = false

    var body: some View {
        Form {
            Section {
                Button { pickingAvatar = true } label: {
                    VStack(spacing: 10) {
                        AccountAvatarView(avatar: avatar, firstName: firstName, size: 96)
                            .opacity(isSavingAvatar ? 0.5 : 1)
                            .overlay { if isSavingAvatar { ProgressView() } }
                        Text("Modifier")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.tint)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .disabled(isSavingAvatar)
                .accessibilityLabel("Modifier l'avatar")
                .accessibilityIdentifier("profile-avatar")
                .listRowBackground(Color.clear)
            }

            Section {
                if let firstName, !firstName.isEmpty {
                    LabeledInfoRow(title: "Prénom", value: firstName, icon: "person.fill")
                }
                if let displayName, !displayName.isEmpty {
                    LabeledInfoRow(title: "Nom", value: displayName, icon: "person.text.rectangle.fill")
                }
                if let email, !email.isEmpty {
                    LabeledInfoRow(title: "Email", value: email, icon: "envelope.fill")
                }
                LabeledInfoRow(title: "Identifiant", value: shortUid, icon: "key.fill")
            } header: {
                Text("Compte")
            }

            Section {
                SignOutButton { Task { await onAction(.signOut) } }
                // The dialog hangs off the button that opens it, so it pops out
                // of the row instead of floating mid-screen.
                DeleteAccountButton(isDeleting: isDeletingAccount) {
                    showDeleteConfirmation = true
                }
                .confirmationDialog(
                    "Supprimer définitivement le compte ?",
                    isPresented: $showDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Supprimer mon compte", role: .destructive) {
                        Task { await onAction(.deleteAccount) }
                    }
                    .accessibilityIdentifier("confirm-delete-account")
                    Button("Annuler", role: .cancel) {}
                } message: {
                    Text(
                        "Votre bibliothèque, vos notes et vos séries seront effacées sans possibilité de récupération. Un abonnement Premium éventuel n'est pas résilié et reste à annuler dans l'App Store."
                    )
                }
            } footer: {
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Profil")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $pickingAvatar) {
            AvatarPickerSheet(current: avatar, firstName: firstName) { newAvatar in
                Task { await onAction(.changeAvatar(newAvatar)) }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProfileSettingsPage(
            firstName: "Thibaut", avatar: .hero(.holmes), isSavingAvatar: false,
            displayName: "Thibaut Mottet", email: "lecteur@example.com",
            shortUid: "a1b2c3d4", isDeletingAccount: false, errorMessage: nil
        ) { _ in }
    }
}

#Preview("Deleting") {
    NavigationStack {
        ProfileSettingsPage(
            firstName: "Thibaut", avatar: .initials, isSavingAvatar: false, displayName: nil, email: nil, shortUid: "a1b2c3d4",
            isDeletingAccount: true, errorMessage: nil
        ) { _ in }
    }
}
