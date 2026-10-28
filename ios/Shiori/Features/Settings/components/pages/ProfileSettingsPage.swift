import SwiftUI

/// Everything the profile page can ask for.
enum ProfileSettingsAction {
    case changeAvatar(AccountAvatar)
    case signOut
    case deleteAccount
}

/// The account behind the library: its face, its name, and the two ways out —
/// signing out, which keeps everything, and deleting, which keeps nothing. The
/// email is left out: Apple's sign-in often hands a relay address the reader
/// never chose. The account id hides behind a button, there for a support
/// message and nothing else.
struct ProfileSettingsPage: View {
    let firstName: String?
    let avatar: AccountAvatar
    let isSavingAvatar: Bool
    let displayName: String?
    /// The first eight characters of the account id: enough to name it in a
    /// support message, short enough to read aloud.
    let shortUid: String
    let isDeletingAccount: Bool
    let errorMessage: String?
    let onAction: (ProfileSettingsAction) async -> Void

    @State private var showDeleteConfirmation = false
    @State private var pickingAvatar = false
    @State private var showsUid = false

    /// The full name Apple gave, else the first name the reader typed.
    private var name: String? {
        [displayName, firstName].compactMap { $0 }.first { !$0.isEmpty }
    }

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
                if let name {
                    LabeledInfoRow(title: "Nom", value: name, icon: "person.fill")
                }
                if showsUid {
                    LabeledInfoRow(title: "Identifiant", value: shortUid, icon: "key.fill")
                        .textSelection(.enabled)
                } else {
                    Button { withAnimation { showsUid = true } } label: {
                        Label("Afficher l'identifiant", systemImage: "key.fill")
                    }
                    .accessibilityIdentifier("profile-show-uid")
                }
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
            displayName: "Thibaut Mottet",
            shortUid: "a1b2c3d4", isDeletingAccount: false, errorMessage: nil
        ) { _ in }
    }
}

#Preview("Deleting") {
    NavigationStack {
        ProfileSettingsPage(
            firstName: "Thibaut", avatar: .initials, isSavingAvatar: false, displayName: nil, shortUid: "a1b2c3d4",
            isDeletingAccount: true, errorMessage: nil
        ) { _ in }
    }
}
