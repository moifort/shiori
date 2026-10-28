import SwiftUI

extension EnvironmentValues {
    /// The first name the reader gave at onboarding. Set at the root
    /// (`AuthRoot`) from the launch request, which reads it off the same account
    /// document as the routing flags, so the profile settings show it without a
    /// request of their own. Nil before onboarding, and for an account that
    /// never gave one.
    @Entry var accountFirstName: String? = nil
    /// The reader's avatar, from the same launch request: the home's toolbar
    /// draws it, the profile settings change it.
    @Entry var accountAvatar: AccountAvatar = .initials
    /// Draws a new avatar everywhere at once, once the server keeps it.
    @Entry var showAccountAvatar = ShowAccountAvatar { _ in }
}

/// Draws a new avatar everywhere at once. Wrapped so the environment can tell
/// it unchanged: a bare closure would redraw every reader of it on each update.
struct ShowAccountAvatar: Equatable {
    let show: (AccountAvatar) -> Void

    func callAsFunction(_ avatar: AccountAvatar) { show(avatar) }

    static func == (_: Self, _: Self) -> Bool { true }
}
