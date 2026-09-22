import Foundation

/// Where a book stands for its reader. The cases are ordered as the pile is
/// worked through, which is the order every picker and filter presents.
/// `dropped` is a book stopped for good, the reader not having liked it: it is
/// set from the book's menu rather than the segmented picker, which holds the
/// states a book moves through.
enum ReadingStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case toRead
    case reading
    case read
    case dropped

    /// The states a book moves through, as the picker offers them.
    static let progression: [ReadingStatus] = [.toRead, .reading, .read]

    var id: String { rawValue }

    var label: String {
        switch self {
        case .toRead: String(localized: "À lire")
        case .reading: String(localized: "En cours")
        case .read: String(localized: "Lu")
        case .dropped: String(localized: "Abandonné")
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
        case .dropped: "xmark"
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

    /// The list a picker offers: by label, in the reader's language, so a genre
    /// is found where the eye expects it rather than where the server declares
    /// it. `other` closes the list, as a catch-all does.
    static var alphabetical: [BookGenre] {
        allCases
            .filter { $0 != .other }
            .sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
            + [.other]
    }

    var label: String {
        switch self {
        case .fantasy: String(localized: "Fantastique")
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

/// Where the reader stands on a saga: not started, working through it, or done
/// with it. Derived by the server from what they own, never stored.
enum SeriesState: String, Codable, CaseIterable, Identifiable, Sendable {
    case notStarted
    case inProgress
    case complete

    var label: String {
        switch self {
        case .notStarted: String(localized: "À lire")
        case .inProgress: String(localized: "En cours")
        case .complete: String(localized: "Terminée")
        }
    }

    var id: String { rawValue }

    /// The state as a section of the Series tab names its sagas.
    var shelfTitle: String {
        switch self {
        case .notStarted: String(localized: "À lire")
        case .inProgress: String(localized: "En cours")
        case .complete: String(localized: "Terminées")
        }
    }

    /// The same symbols as the reading statuses they mirror.
    var symbol: String {
        switch self {
        case .notStarted: ReadingStatus.toRead.symbol
        case .inProgress: ReadingStatus.reading.symbol
        case .complete: ReadingStatus.read.symbol
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
    /// The rating the reader gave the book's saga, lent to the volumes they left
    /// unrated. Kept apart from `rating` so the edit form still knows whether
    /// the book itself was rated.
    var seriesRating: Int?
    /// A book the reader keeps close, independent of the rating: a five-star
    /// novel one never wants to open again and a three-star one kept for what it
    /// meant are both real, and one field cannot say both.
    var favorite: Bool = false
    var note: String?
    var hidden: Bool = false
    var addedAt: Date?
    var startedAt: Date?
    var finishedAt: Date?
    /// The date the Library tab files the book under, as the server decides it:
    /// finished, else started, else added. Only the list rows carry it.
    var shelvedAt: Date?

    /// The stars a row draws: the book's own rating, else its saga's. A saga
    /// rated as a whole rates each of its unrated volumes, and a rating given
    /// to the book itself always wins.
    var shownRating: Int? { rating ?? seriesRating }

    /// The stars drawn are the saga's, not the book's own: drawn dimmer, so a
    /// judgement given is told from one lent.
    var ratingIsInherited: Bool { rating == nil && seriesRating != nil }

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

/// One saga of the reader's library, or a shelf of standalone books — what the
/// Series and Favorites screens group the library into.
struct LibrarySection: Identifiable, Codable, Sendable {
    /// The saga and the language together, or the first book of a standalone
    /// shelf. The saga alone is not an identity any more: a saga held in two
    /// languages makes two sections, and SwiftUI would take them for one row
    /// redrawn twice. Nor is "standalone": the list is tiered by reading
    /// status, and each tier trails its sagas with a shelf of its own.
    var id: String {
        seriesId.map { "\($0)|\(language?.rawValue ?? "")" } ?? "standalone|\(books.first?.id ?? "")"
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

/// One place in a saga's cover strip: a volume the reader owns, or one of the
/// cycle they do not, drawn as a dimmed placeholder.
enum SeriesStripItem: Identifiable, Hashable, Codable, Sendable {
    case owned(Book)
    /// A volume the reader lacks. `number` is its place along the spine, nil
    /// for an unnumbered related work; `forthcoming` marks one announced for a
    /// year that has not come yet.
    case missing(key: String, number: Int?, title: String, forthcoming: Bool)

    var id: String {
        switch self {
        case let .owned(book): book.id
        case let .missing(key, _, _, _): "missing-\(key)"
        }
    }

    /// Every volume the saga screen lists, in its order: the spine, announced
    /// volumes included, then the prequels, novellas and companions. Each
    /// takes the reader's book when they have it and a placeholder when they
    /// do not; owned volumes the catalogue does not list follow. Just the owned
    /// volumes when the saga has no catalogue yet — the saga screen is what
    /// builds it, and a scroll through the tab must not pay for one per row.
    static func strip(owned: [Book], catalogue: [Volume], currentYear: Int) -> [SeriesStripItem] {
        guard !catalogue.isEmpty else { return owned.map { .owned($0) } }
        var placed = Set<String>()
        var items: [SeriesStripItem] = []
        for volume in catalogue {
            if let book = owned.first(where: { !placed.contains($0.id) && volume.matches($0) }) {
                items.append(.owned(book))
                placed.insert(book.id)
            } else {
                items.append(.missing(
                    key: volume.id,
                    number: volume.number,
                    title: volume.title,
                    forthcoming: volume.isForthcoming(asOf: currentYear)
                ))
            }
        }
        items += owned.filter { !placed.contains($0.id) }.map { .owned($0) }
        return items
    }
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

    /// Whether the reader's book is this volume: the same kind at the same
    /// number, or, for an unnumbered related work, the same title.
    func matches(_ book: Book) -> Bool {
        let kind = book.series?.kind ?? .main
        guard kind == self.kind else { return false }
        if let number { return book.series?.volume == number }
        return book.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            == title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
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
    /// Drawn from the reader's own count of the volumes rather than from the
    /// world: nobody has catalogued the saga, and they said how many volumes it
    /// has. Their volumes sit at their numbers and the saga's name stands in
    /// for the rest, with no year and no description.
    var isProvisional = false
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
    /// How many volumes the saga has by the reader's own count, for a saga
    /// nobody has catalogued. Nil until they say.
    var volumeCount: Int?
}

/// A saga the reader follows. Its identity comes from their own books, not from
/// the catalogue: an Audible import and a book typed by hand both name a saga
/// without describing it, and reading the catalogue first lost every one of them.
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
    /// Nil when every owned volume is read and no catalogue says whether more
    /// exist: whether the saga is over is precisely what is unknown then.
    let state: SeriesState?
    /// The genre most of the owned volumes carry. Nil when none of them has one.
    let genre: BookGenre?
    let ownedCount: Int
    /// The latest date any owned volume is shelved on — finished, else started,
    /// else added: what the Series tab is ordered and cut into months by.
    var shelvedAt: Date?
    /// The owned volumes in the order the saga runs, each with its cover and
    /// status. Only the Series tab asks for them — every one costs the server
    /// a signed cover URL — so they are empty anywhere else.
    var volumes: [Book] = []
    /// What the tab's cover strip draws: the owned volumes and, between them,
    /// the published volumes of the cycle the reader does not have, in the
    /// order of the cycle. Just the owned volumes when no catalogue exists.
    var strip: [SeriesStripItem] = []
    /// Nil until the reader says something about the saga. The two rows of a
    /// saga held in two languages carry the same one.
    var opinion: SeriesOpinion?
}
