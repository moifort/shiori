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

    /// The filled symbol reads as a state rather than an action, which matters
    /// on a row where it sits next to the rating.
    var symbol: String {
        switch self {
        case .toRead: "bookmark"
        case .reading: "book"
        case .read: "checkmark.circle.fill"
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
struct SeriesMembership: Identifiable, Hashable, Sendable {
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
struct Book: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let authors: [String]
    var publisher: String?
    var firstPublishedIn: Int?
    var synopsis: String?
    var genres: [String] = []
    var pageCount: Int?
    var isbn13: String?
    var series: SeriesMembership?
    /// The reader's own photo of the cover, behind a URL that expires after an
    /// hour. Absent for a book added by hand or from a catalogue — those get a
    /// typographic placeholder instead.
    var coverURL: URL?
    var status: ReadingStatus
    var rating: Int?
    var note: String?
    var hidden: Bool = false
    var addedAt: Date?
    var startedAt: Date?
    var finishedAt: Date?

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
struct LibrarySection: Identifiable, Sendable {
    /// The saga id, or a fixed key for the standalone shelf — a section needs a
    /// stable identity for SwiftUI, and the shelf has no series to borrow one from.
    var id: String { seriesId ?? "standalone" }
    let seriesId: String?
    let seriesName: String?
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

/// A saga the reader follows, paired with the state derived from what they own.
struct FollowedSeries: Identifiable, Sendable {
    var id: String { series.id }
    let series: BookSeries
    let state: SeriesState
    let ownedCount: Int
}
