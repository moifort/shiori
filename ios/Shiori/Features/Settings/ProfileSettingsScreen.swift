import SwiftUI

/// The account behind the library, connected: who it is from the auth
/// session, and the two ways out through `ProfileSettingsViewModel`.
struct ProfileSettingsScreen: View {
    @Environment(AuthSession.self) private var authSession
    /// Read at launch with the routing flags: this screen asks the server nothing.
    @Environment(\.accountFirstName) private var firstName
    @Environment(\.accountAvatar) private var avatar
    @Environment(\.showAccountAvatar) private var showAvatar
    @State private var viewModel: ProfileSettingsViewModel

    init(client: SettingsClient = .live) {
        _viewModel = State(initialValue: ProfileSettingsViewModel(client: client))
    }

    var body: some View {
        ProfileSettingsPage(
            firstName: firstName,
            avatar: viewModel.savingAvatar ?? avatar,
            isSavingAvatar: viewModel.savingAvatar != nil,
            displayName: authSession.user?.displayName,
            email: authSession.user?.email,
            shortUid: String((authSession.user?.uid ?? "").prefix(8)),
            isDeletingAccount: viewModel.isDeletingAccount,
            errorMessage: viewModel.errorMessage
        ) { action in
            switch action {
            case let .changeAvatar(newAvatar): await viewModel.changeAvatar(newAvatar, show: showAvatar.callAsFunction)
            case .signOut: await viewModel.signOut(endSession: authSession.signOut)
            case .deleteAccount: await viewModel.deleteAccount(endSession: authSession.signOut)
            }
        }
    }
}
