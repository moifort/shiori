import Foundation

/// Everything a narrator's page draws: who they are, and the reader's
/// recordings in their voice, to rate and to heart as an author's books are.
struct NarratorPage: Sendable {
    let key: String
    /// The spelling most of the reader's recordings use.
    let name: String
    /// Their photograph, when Wikipedia has one. Nil draws their initials.
    let portraitURL: URL?
    /// The reader hearted the narrator: the heart in the bar.
    var favorite: Bool
    /// Recordings of theirs in the library.
    let bookCount: Int
    /// Recordings of theirs the reader has listened to.
    let readCount: Int
    let seriesCount: Int
    /// The mean of the stars given to their recordings and sagas. Nil when
    /// nothing of theirs is rated.
    let averageRating: Double?
    /// The reader's sagas heard in their voice, listened into first.
    let sagas: [FollowedSeries]
    /// The reader's recordings of theirs outside any saga, listened ones first.
    let books: [Book]
    var nationality: String?
    var birthYear: Int?
    var deathYear: Int?
    /// Who they are as a voice, written by the AI the first time anybody
    /// opened their page.
    var biography: String?
    /// Nobody had described the narrator: only the reader's recordings, while
    /// the AI builds the catalogue the screen asks for next.
    var isAwaitingCatalogue = false

    /// The initials drawn until they have a portrait, as an author's are:
    /// the first letter of the first and last words.
    var initials: String {
        let words = name.split(separator: " ")
        let ends = words.count > 1 ? [words.first, words.last] : [words.first]
        return ends.compactMap { $0?.first }.map(String.init).joined().uppercased()
    }

    /// What the edit form opens on.
    var facts: PersonFacts {
        PersonFacts(nationality: nationality, birthYear: birthYear, deathYear: deathYear, biography: biography)
    }

    /// The cover the hero's ground is blurred from: the first the page draws.
    var backdropURL: URL? {
        let covers: [URL?] = sagas.map(\.cardCoverURL) + books.map(\.coverURL)
        return covers.compactMap(\.self).first ?? portraitURL
    }
}
