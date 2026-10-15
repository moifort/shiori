import Foundation

/// The two ways out of the account: signing out, which keeps everything, and
/// deleting, which keeps nothing. Ending the session is the caller's, handed
/// in as `endSession`: the ViewModel never holds the auth session itself.
@MainActor
@Observable
final class ProfileSettingsViewModel {
    private(set) var isDeletingAccount = false
    /// What went wrong, said under the buttons.
    private(set) var errorMessage: String?

    private let client: SettingsClient

    init(client: SettingsClient) {
        self.client = client
    }

    func signOut(endSession: () throws -> Void) async {
        errorMessage = nil
        // While the session still stands: the server must stop pushing to
        // this phone before it forgets who holds it.
        await client.forgetDevice()
        do {
            try endSession()
        } catch {
            errorMessage = reportError(error)
        }
    }

    func deleteAccount(endSession: () throws -> Void) async {
        isDeletingAccount = true
        errorMessage = nil
        do {
            try await client.deleteAccount()
        } catch {
            // The server may have finished and only its answer been lost — a
            // timeout, the app sent to the background. If the account is gone,
            // the deletion happened: sign out as if the answer had arrived.
            if await client.accountIsGone() { return }
            errorMessage = reportError(error)
            isDeletingAccount = false
            return
        }
        // Everything is erased, the Firebase user last: drop the now-invalid
        // session and route back to the login screen.
        do {
            try endSession()
        } catch {
            errorMessage = reportError(error)
            isDeletingAccount = false
        }
    }
}
