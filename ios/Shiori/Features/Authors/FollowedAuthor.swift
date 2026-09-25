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

    /// The author's initials, drawn in the avatar until the author has a
    /// portrait of their own: the first letter of the first and last words, so
    /// a middle initial is skipped — "Ursula K. Le Guin" is UG, not UK.
    var initials: String {
        let words = name.split(separator: " ")
        let ends = words.count > 1 ? [words.first, words.last] : [words.first]
        return ends.compactMap { $0?.first }.map(String.init).joined().uppercased()
    }
}
