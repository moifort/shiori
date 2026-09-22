import SwiftUI

/// The account behind the library: who it is, and the two ways out — signing
/// out, which keeps everything, and deleting, which keeps nothing.
struct ProfileSettingsView: View {
    @Environment(AuthSession.self) private var authSession
    /// Read at launch with the routing flags: this screen asks the server nothing.
    @Environment(\.accountFirstName) private var firstName

    @State private var signOutError: String?
    @State private var deleteError: String?
    @State private var showDeleteConfirmation = false
    @State private var isDeletingAccount = false

    var body: some View {
        Form {
            Section {
                if let firstName, !firstName.isEmpty {
                    LabeledInfoRow(title: "Prénom", value: firstName, icon: "person.fill")
                }
                if let displayName = authSession.user?.displayName, !displayName.isEmpty {
                    LabeledInfoRow(title: "Nom", value: displayName, icon: "person.text.rectangle.fill")
                }
                if let email = authSession.user?.email, !email.isEmpty {
                    LabeledInfoRow(title: "Email", value: email, icon: "envelope.fill")
                }
                LabeledInfoRow(title: "Identifiant", value: shortUid, icon: "key.fill")
            } header: {
                Text("Compte")
            }

            Section {
                SignOutButton(action: signOut)
            } footer: {
                if let signOutError {
                    Text(signOutError).foregroundStyle(.red)
                }
            }

            Section {
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
                        Task { await deleteAccount() }
                    }
                    .accessibilityIdentifier("confirm-delete-account")
                    Button("Annuler", role: .cancel) {}
                } message: {
                    Text(
                        "Votre bibliothèque, vos notes et vos séries seront effacées sans possibilité de récupération. Un abonnement Premium éventuel n'est pas résilié et reste à annuler dans l'App Store."
                    )
                }
            } footer: {
                if let deleteError {
                    Text(deleteError).foregroundStyle(.red)
                } else {
                    Text(
                        "Supprime définitivement le compte et toutes ses données. Cette action est irréversible. Un abonnement Premium n'est pas résilié : il reste à annuler dans les réglages de l'App Store."
                    )
                }
            }
        }
        .navigationTitle("Profil")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// The first eight characters: enough to name the account in a support
    /// message, short enough to read aloud.
    private var shortUid: String {
        String((authSession.user?.uid ?? "").prefix(8))
    }

    private func signOut() {
        signOutError = nil
        do {
            try authSession.signOut()
        } catch {
            signOutError = reportError(error)
        }
    }

    private func deleteAccount() async {
        isDeletingAccount = true
        deleteError = nil
        do {
            try await SettingsAPI.deleteAccount()
            // The server has deleted the Firebase user; sign out locally to drop
            // the now-invalid session and route back to the login screen.
            try authSession.signOut()
        } catch {
            deleteError = reportError(error)
            isDeletingAccount = false
        }
    }
}
