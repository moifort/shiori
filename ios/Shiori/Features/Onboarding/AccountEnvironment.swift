import SwiftUI

extension EnvironmentValues {
    /// The first name the reader gave at onboarding. Set at the root
    /// (`AuthRoot`) from the launch request, which reads it off the same account
    /// document as the routing flags, so the profile settings show it without a
    /// request of their own. Nil before onboarding, and for an account that
    /// never gave one.
    @Entry var accountFirstName: String? = nil
}
