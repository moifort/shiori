import Foundation

/// When a position the player sent should tell the library it changed.
///
/// The server moves the book with every position it is sent: a book on the
/// pile goes under way past its first minute, its progress follows, and it is
/// read once heard to its closing credits. Accueil and the lists only show it
/// once told. Telling them at every half-minute save would reload every open
/// tab twice a minute, so they hear of it when the reader stops — a pause, a
/// seek, the app left, another title — the first time a listen passes its
/// first minute, and at the end.
struct ListeningLibraryNotice {
    /// The server's own threshold for a book taken off the pile.
    static let startedAfter: TimeInterval = 60
    /// The server's own margin for a book heard to its end.
    static let finishedWithin: TimeInterval = 3 * 60

    /// Titles whose first minute this listen already announced.
    private var announced: Set<String> = []

    /// Whether this sent position should be announced. `periodic` is the
    /// half-minute save of a title playing; every other save is the reader
    /// stopping somewhere.
    mutating func shouldAnnounce(
        asin: String,
        position: TimeInterval,
        duration: TimeInterval,
        periodic: Bool
    ) -> Bool {
        if duration > 0, position >= duration - Self.finishedWithin { return true }
        guard position >= Self.startedAfter else { return false }
        let first = announced.insert(asin).inserted
        return first || !periodic
    }
}
