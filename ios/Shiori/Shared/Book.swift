import Foundation

/// Where a book stands for its reader. The three cases are ordered as the pile
/// is worked through, which is the order every picker and filter presents.
enum ReadingStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case toRead
    case reading
    case read

    var id: String { rawValue }

    var label: String {
        switch self {
        case .toRead: String(localized: "À lire")
        case .reading: String(localized: "En cours")
        case .read: String(localized: "Lu")
        }
    }

    /// One symbol per status, used everywhere the status is drawn — the cover
    /// badge, the status picker, the library filter — so a reader learns it once.
    /// Filled, because it names a state rather than an action.
    var symbol: String {
        switch self {
        case .toRead: "bookmark.fill"
        case .reading: "book.fill"
        case .read: "checkmark"
        }
    }
}

/// What kind of object the reader holds. Drawn stories are split into the three
/// traditions readers shelve apart; `book` covers everything in prose.
enum BookFormat: String, Codable, CaseIterable, Identifiable, Sendable {
    case book
    case ebook
    case audiobook
    case bandeDessinee
    case comic
    case manga

    var id: String { rawValue }

    var label: String {
        switch self {
        case .book: String(localized: "Livre")
        case .ebook: String(localized: "Livre numérique")
        case .audiobook: String(localized: "Livre audio")
        case .bandeDessinee: String(localized: "BD")
        case .comic: String(localized: "Comics")
        case .manga: String(localized: "Manga")
        }
    }

    var symbol: String {
        switch self {
        case .book: "book.closed"
        case .ebook: "ipad"
        case .audiobook: "headphones"
        case .bandeDessinee: "text.bubble"
        case .comic: "bolt"
        case .manga: "character.book.closed.ja"
        }
    }
}

/// What a book is about, from the closed list the server holds. Nuance lives in
/// the free subgenres beside it; the object (manga, BD) is the format.
enum BookGenre: String, Codable, CaseIterable, Identifiable, Sendable {
    case fantasy
    case scienceFiction
    case horror
    case crime
    case thriller
    case romance
    case historicalFiction
    case adventure
    case literaryFiction
    case humor
    case poetry
    case drama
    case biography
    case history
    case essay
    case science
    case selfHelp
    case business
    case art
    case cooking
    case travel
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fantasy: String(localized: "Fantasy")
        case .scienceFiction: String(localized: "Science-fiction")
        case .horror: String(localized: "Horreur")
        case .crime: String(localized: "Polar")
        case .thriller: String(localized: "Thriller")
        case .romance: String(localized: "Romance")
        case .historicalFiction: String(localized: "Roman historique")
        case .adventure: String(localized: "Aventure")
        case .literaryFiction: String(localized: "Littérature")
        case .humor: String(localized: "Humour")
        case .poetry: String(localized: "Poésie")
        case .drama: String(localized: "Théâtre")
        case .biography: String(localized: "Biographie")
        case .history: String(localized: "Histoire")
        case .essay: String(localized: "Essai")
        case .science: String(localized: "Sciences")
        case .selfHelp: String(localized: "Développement personnel")
        case .business: String(localized: "Économie")
        case .art: String(localized: "Art")
        case .cooking: String(localized: "Cuisine")
        case .travel: String(localized: "Voyage")
        case .other: String(localized: "Autre")
        }
    }
}

/// Where a volume sits in a saga. Only `main` belongs to the numbered spine;
/// everything else orbits it and usually carries no number.
enum VolumeKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case main
    case prequel
    case spinOff
    case novella
    case companion

    var id: String { rawValue }

    var label: String {
        switch self {
        case .main: String(localized: "Tome")
        case .prequel: String(localized: "Préquelle")
        case .spinOff: String(localized: "Hors-série")
        case .novella: String(localized: "Nouvelle")
        case .companion: String(localized: "Compagnon")
        }
    }
}

/// Whether the reader is still working through a saga. Derived by the server
/// from what they own, never stored.
enum SeriesState: String, Codable, Sendable {
    case inProgress
    case complete

    var label: String {
        switch self {
        case .inProgress: String(localized: "En cours")
        case .complete: String(localized: "Terminée")
        }
    }
}

/// A book's place in a saga, carried on the book itself so a list can group
/// without fetching a catalogue per row.
struct SeriesMembership: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let volume: Int?
    let kind: VolumeKind

    /// How the volume announces itself in a section: "Tome 3", or just the kind
    /// when it sits outside the numbering.
    var label: String {
        guard let volume else { return kind.label }
        return "\(kind.label) \(volume)"
    }
}

/// A book as its reader holds it: the public facts and their own judgment on the
/// same record, because the record belongs to the reader rather than the world.
struct Book: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let title: String
    let authors: [String]
    var format: BookFormat = .book
    var publisher: String?
    var firstPublishedIn: Int?
    var synopsis: String?
    var genre: BookGenre?
    var subgenres: [String] = []
    var pageCount: Int?
    /// An audiobook's running time, in whole minutes. Only Audible knows it: a
    /// scanned cover does not say how long the recording is.
    var durationMinutes: Int?
    /// Who reads the recording. Empty on anything but an audiobook, and empty on
    /// an audiobook no Audible import ever named.
    var narrators: [String] = []
    var isbn13: String?
    /// The language of this edition. Nil on every book catalogued before the scan
    /// started reading it off the cover, and on any edition in a language the
    /// closed list does not carry.
    var language: BookLanguage?
    var series: SeriesMembership?
    /// The cover to draw: the reader's own photo, or the publisher's cover found by
    /// ISBN at scan time. Absent for a book added by hand or from a catalogue, and
    /// either may fail to load — both cases get the typographic placeholder.
    var coverURL: URL?
    var status: ReadingStatus
    var rating: Int?
    /// A book the reader keeps close, independent of the rating: a five-star
    /// novel one never wants to open again and a three-star one kept for what it
    /// meant are both real, and one field cannot say both.
    var favorite: Bool = false
    var note: String?
    var hidden: Bool = false
    var addedAt: Date?
    var startedAt: Date?
    var finishedAt: Date?

    /// Who reads the recording, as one line. Nil rather than a placeholder: a
    /// book with no narrator draws no line at all, where an author is always
    /// credited to somebody even when nobody knows who.
    var narratorLine: String? {
        narrators.isEmpty ? nil : narrators.joined(separator: ", ")
    }

    /// The running time as a reader says it out loud — "8 h 12", "47 min". Hours
    /// and minutes rather than a bare minute count: nobody hears "492 minutes"
    /// as a length.
    var durationLabel: String? {
        guard let durationMinutes else { return nil }
        let hours = durationMinutes / 60
        let minutes = durationMinutes % 60
        if hours == 0 { return String(localized: "\(minutes) min") }
        if minutes == 0 { return String(localized: "\(hours) h") }
        return String(localized: "\(hours) h \(minutes)")
    }

    /// Authors as one line. Falls back to a placeholder rather than an empty
    /// string so a row never collapses to a bare title with a gap under it.
    var authorLine: String {
        authors.isEmpty ? String(localized: "Auteur inconnu") : authors.joined(separator: ", ")
    }

    /// The two letters drawn on the placeholder cover: the title's initial and
    /// the author's, which together make most shelves scannable at a glance.
    var initials: String {
        let titleInitial = title.first.map(String.init) ?? ""
        let authorInitial = authors.first?.first.map(String.init) ?? ""
        return (titleInitial + authorInitial).uppercased()
    }
}

/// One heading of the library list: a saga the reader owns volumes of, or the
/// trailing shelf of standalone books.
struct LibrarySection: Identifiable, Codable, Sendable {
    /// The saga and the language together, or the first book of a standalone
    /// shelf. The saga alone is not an identity any more: a saga held in two
    /// languages makes two sections, and SwiftUI would take them for one row
    /// redrawn twice. Nor is "standalone": the list is tiered by reading
    /// status, and each tier trails its sagas with a shelf of its own.
    var id: String {
        seriesId.map { "\($0)|\(language?.rawValue ?? "")" } ?? "standalone|\(books.first?.id ?? "")"
    }

    /// Whether two sections are the same heading — what stitches a section
    /// cut across two pages back together. Not the id, which a standalone
    /// shelf takes from its first book.
    func continues(_ other: LibrarySection) -> Bool {
        seriesId == other.seriesId && language == other.language
    }
    let seriesId: String?
    let seriesName: String?
    /// The language its volumes are in. Nil on the standalone shelf, and nil on
    /// a saga whose volumes carry no recorded language.
    var language: BookLanguage?
    /// What the reader makes of the saga, drawn on the heading. Nil on the
    /// standalone shelf and on a saga they have said nothing about.
    var opinion: SeriesOpinion?
    let books: [Book]
}

/// One entry of a saga catalogue, owned or not. Most of these are books the
/// reader does not own: the catalogue lists what exists in the world, and
/// nothing enters a library until they add it.
struct Volume: Identifiable, Hashable, Sendable {
    var id: String { "\(kind.rawValue)-\(number.map(String.init) ?? title)" }
    let number: Int?
    let title: String
    let publishedIn: Int?
    let kind: VolumeKind

    /// A volume announced for a year that has not arrived yet. Kept in the
    /// catalogue on purpose: it is what a release alert will attach to.
    func isForthcoming(asOf year: Int) -> Bool {
        guard let publishedIn else { return false }
        return publishedIn > year
    }
}

/// The shared catalogue of a saga. A public fact with no reader in it, which is
/// why one fetch serves every reader of that saga.
struct BookSeries: Identifiable, Sendable {
    let id: String
    let name: String
    let author: String
    var description: String?
    /// The numbered main volumes, ascending.
    var spine: [Volume] = []
    /// Prequels, spin-offs, novellas and companions — everything off the spine.
    var relatedWorks: [Volume] = []
}

/// What one reader makes of one saga — never part of the shared catalogue, which
/// is a fact about the world with no reader in it.
///
/// The rating is a judgement of the saga itself and deliberately not the average
/// of the volume ratings: a cycle can be worth more than its books, the shape
/// only showing at the end, or rather less when three good volumes are followed
/// by four that should not exist.
///
/// Held per saga, never per saga and language: the split the library draws by
/// language is about editions on a shelf, and this is about the work.
struct SeriesOpinion: Sendable, Equatable, Codable {
    let seriesId: String
    var rating: Int?
    var favorite: Bool = false
}

/// A saga the reader follows. Its identity comes from their own books, not from
/// the catalogue: an Audible import and a book typed by hand both name a saga
/// without describing it, and reading the catalogue first lost every one of them.
/// Where the reader stands on a saga's published spine.
struct SeriesProgressCount: Codable, Sendable, Equatable {
    let read: Int
    let total: Int
}

struct FollowedSeries: Identifiable, Codable, Sendable {
    /// The saga and the language together. The saga alone is not an identity:
    /// held in two languages it follows as two rows, and SwiftUI would take them
    /// for one row redrawn twice.
    var id: String { "\(seriesId)|\(language?.rawValue ?? "")" }
    let seriesId: String
    let name: String
    /// Taken from a volume the reader owns, which is what answers for a saga the
    /// catalogue has never described.
    let author: String?
    /// The language the reader holds these volumes in. Nil on a saga whose
    /// volumes carry no recorded language.
    let language: BookLanguage?
    /// Nil when no catalogue exists to derive it from: which volumes the saga has
    /// is precisely what is unknown then.
    let state: SeriesState?
    /// The genre most of the owned volumes carry: what the Series tab is
    /// sectioned on. Nil when none of them has one.
    let genre: BookGenre?
    /// How many of the published spine volumes are read, out of how many. Nil
    /// without a catalogue, like the state, and for the same reason.
    let progress: SeriesProgressCount?
    let ownedCount: Int
    /// Nil until the reader says something about the saga. The two rows of a
    /// saga held in two languages carry the same one.
    var opinion: SeriesOpinion?
}
