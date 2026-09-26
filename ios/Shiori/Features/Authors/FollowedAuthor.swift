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
    /// The letter of the alphabet index they are filed under, as a bookshop
    /// files them — Balzac under B, Le Guin under L — or "#". Filed by the
    /// server, which orders the alphabetical list on the same rule.
    let indexLetter: String
    /// Their photograph, once somebody has opened their page and Wikipedia had
    /// one. Nil until then: the row draws their initials.
    var portraitURL: URL?
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

/// Everything an author's page draws: who they are, what the reader holds and
/// thinks of their work, and what they could add.
struct AuthorPage: Sendable {
    let author: FollowedAuthor
    /// Books of theirs the reader has read.
    let readCount: Int
    let nationality: String?
    let birthYear: Int?
    let deathYear: Int?
    let biography: String?
    /// The reader's sagas of this author, read into first, as the Series tab
    /// draws them.
    let sagas: [FollowedSeries]
    /// Their sagas the reader holds nothing of on paper. Nothing is offered
    /// among the recordings: the catalogue does not know which titles were
    /// recorded, and the Audio side showed the same offers as the Livre one.
    let printSagasNotHeld: [AuthorSeries]

    func sagasNotHeld(in format: AuthorShelfFormat) -> [AuthorSeries] {
        format == .audio ? [] : printSagasNotHeld
    }

    /// Their other books outside any saga, offered on the Livre side only.
    func booksNotHeld(in format: AuthorShelfFormat) -> [AuthorWork] {
        format == .audio ? [] : booksNotHeld
    }
    /// The reader's books of theirs outside any saga, read ones first.
    let books: [Book]
    /// Their other books outside any saga, which the reader does not hold.
    let booksNotHeld: [AuthorWork]
}

/// A saga the author wrote that the reader holds nothing of.
struct AuthorSeries: Identifiable, Sendable {
    /// The id its catalogue is keyed on: a volume added with it joins the saga.
    let id: String
    let name: String
    /// The author as the catalogue spells them, which the id was folded from:
    /// with the name, what the saga screen catalogues the saga from.
    let author: String
    let volumeCount: Int?
    let firstVolumeTitle: String?
    /// The first volume's cover as Open Library shows the work, often the
    /// original edition's. Nil draws the placeholder.
    let coverURL: URL?

    /// How the saga screen names this saga, since the reader holds no volume of it.
    var proposal: SeriesProposal { SeriesProposal(name: name, author: author) }
}

/// A book the author wrote outside any saga, that the reader does not hold.
struct AuthorWork: Identifiable, Sendable {
    var id: String { title }
    let title: String
    let publishedIn: Int?
    /// Its cover as Open Library shows the work, often the original edition's.
    /// Nil draws the placeholder.
    let coverURL: URL?
}
