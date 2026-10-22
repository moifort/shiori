import SwiftUI

extension EnvironmentValues {
    /// Closes the detail a screen is shown as, beside the page it was opened
    /// from on an unfolded iPhone Duo. Nil when the screen is a sheet, which
    /// closes as a sheet does.
    @Entry var closeDetailPane: (@MainActor () -> Void)?
}
