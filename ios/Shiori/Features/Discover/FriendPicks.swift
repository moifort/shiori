import SwiftUI

/// Who among the reader's friends loves one suggestion, the newest heart
/// first — the first is the friend whose copy a tap opens — and whether enough
/// of them do for the flame.
struct FriendLovers: Hashable, Codable, Sendable {
    struct Lover: Hashable, Codable, Sendable {
        let userId: String
        /// Nil for an account that never finished its onboarding.
        let firstName: String?

        var displayName: String { firstName ?? String(localized: "Un lecteur") }
    }

    let friends: [Lover]
    /// A third of the reader's friends hearted it, and two of them at least.
    let lovedByMany: Bool

    /// The friend whose copy stands for it.
    var first: Lover? { friends.first }

    /// "Marie", "Marie et Paul", "Marie +2": short enough for a tile's width.
    var caption: String {
        guard let first else { return "" }
        switch friends.count {
        case 1: return first.displayName
        case 2: return String(localized: "\(first.displayName) et \(friends[1].displayName)")
        default: return "\(first.displayName) +\(friends.count - 1)"
        }
    }
}

/// A book the friends hearted that the reader holds in no format.
struct LovedBook: Identifiable, Hashable, Codable, Sendable {
    let book: FriendBook
    let lovers: FriendLovers

    var id: String { book.id }
}

/// A saga the friends hearted, read or heard, that the reader holds no volume
/// of. Carries its first volume only, the cover its card draws.
struct LovedSaga: Identifiable, Codable, Sendable {
    let saga: FriendSaga
    let lovers: FriendLovers

    var id: String { saga.id }
}

/// An author of a book or a saga the friends hearted, whom the reader holds no
/// book of.
struct LovedAuthor: Identifiable, Hashable, Codable, Sendable {
    let key: String
    let name: String
    /// Nil until somebody opened their page and Wikipedia had a photograph.
    let portraitURL: URL?
    let lovers: FriendLovers

    var id: String { key }

    /// As the Authors shelf draws them: "Ursula K. Le Guin" is UG, not UK.
    var initials: String {
        let words = name.split(separator: " ")
        let ends = words.count > 1 ? [words.first, words.last] : [words.first]
        return ends.compactMap { $0?.first }.map(String.init).joined().uppercased()
    }
}

/// "Coups de cœur de vos amis": what Découvrir suggests from the friends'
/// hearts, whatever the format — a friend's recording is a story the reader
/// may take on paper.
struct FriendPicks: Codable, Sendable {
    var books: [LovedBook] = []
    var sagas: [LovedSaga] = []
    var authors: [LovedAuthor] = []
}
