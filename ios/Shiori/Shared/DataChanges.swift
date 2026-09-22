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
    /// The one refinement: a write to a single book or a single saga carries
    /// a `DataChange` as the notice's object, so a list that knows what it
    /// has open can patch that one row instead of reloading. A notice with no
    /// object may have changed anything.
    static let shioriDataDidChange = Notification.Name("ShioriDataDidChange")
}

/// What a single write changed, when it changed one thing.
enum DataChange: Hashable, Sendable {
    /// One book: its fields, its status, its saga — or the book is gone.
    case book(id: String)
    /// One saga, in every edition: the reader's rating, heart, count of
    /// volumes, whether they follow it, its catalogue — or the saga is gone.
    case series(id: String)
}
