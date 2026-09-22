import Foundation

extension Notification.Name {
    /// Something in the library changed on the server: a book added, corrected,
    /// rated, removed, a saga hearted, an import landed. Posted after every
    /// mutation that came back, so a list left open on another tab redraws
    /// itself before the reader gets back to it, and the dashboard's figures
    /// move with the edit that moved them.
    ///
    /// One name for everything on purpose: the lists are cheap to refetch and
    /// the alternative — naming what changed and having every screen decide
    /// whether it cares — is where stale rows come from.
    ///
    /// The one exception: a write to a single book carries its id as the
    /// notice's object, so the list whose sheet made the edit, and patched the
    /// row from the answer, can skip the reload that would lose its place.
    static let shioriDataDidChange = Notification.Name("ShioriDataDidChange")
}
