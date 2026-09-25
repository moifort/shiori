import Foundation

/// An author the reader holds at least one book of, as the Authors tab draws
/// them: derived by the server from the books on every request, never stored.
struct FollowedAuthor: Identifiable, Codable, Sendable {
    /// The name folded the way the server folds it, so two spellings of one
    /// author are one row.
    let key: String
    var id: String { key }
    /// The spelling most of the reader's books use.
    let name: String
    let bookCount: Int
    let seriesCount: Int
    /// Hearted books plus hearted sagas: what the tab is ranked on first.
    let favoriteCount: Int
    /// The mean of the stars given to their books and sagas. Nil when nothing
    /// of theirs is rated.
    let averageRating: Double?
    /// Their books, newest shelved first, each with its cover and status.
    let books: [Book]
    /// Their latest saga in progress, else their latest finished. Nil when
    /// neither exists.
    let saga: AuthorSaga?

    /// The author's initials, drawn in the avatar until the author has a
    /// portrait of their own: the first letter of the first two words, as a
    /// friend's are.
    var initials: String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }
}

/// The saga shown under an author, with how far the reader is into it: on the
/// catalogue's published spine, or on the volumes owned when there is none.
struct AuthorSaga: Codable, Sendable {
    let series: FollowedSeries
    let readCount: Int
    let totalCount: Int
}
