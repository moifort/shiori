import Foundation

/// The Goodreads shelf a book sits on: every book is on exactly one of these.
enum GoodreadsShelf: String, Sendable, Hashable {
    case read
    case currentlyReading
    case toRead
}

/// How a row of the export stands against the library.
enum GoodreadsVerdict: String, Sendable, Hashable {
    /// Not in the library: it becomes a book, or a wish.
    case new
    /// Already in the library: the record takes what it lacks.
    case held
    /// Maybe a book the library holds: the reader says.
    case uncertain
}

/// One book of a Goodreads export, read by the server, before anything is saved.
struct GoodreadsRow: Identifiable, Sendable, Hashable {
    let key: String
    let title: String
    let authors: [String]
    var seriesName: String?
    var volume: Int?
    var format: BookFormat = .book
    var media: [BookMedium] = [.print]
    var language: BookLanguage?
    var rating: Double?
    var readOn: Date?
    let shelf: GoodreadsShelf
    var dropped = false
    var hasReview = false
    let verdict: GoodreadsVerdict
    var heldBookId: String?
    var heldTitle: String?
    var heldCoverURL: URL?
    var coverURL: URL?

    var id: String { key }

    /// The status the row lands with, or nil when it goes to the wishlist.
    func status(toRead: GoodreadsChoices.ToRead) -> ReadingStatus? {
        if dropped { return .dropped }
        switch shelf {
        case .read: return .read
        case .currentlyReading: return .reading
        case .toRead: return toRead == .pile ? .toRead : nil
        }
    }

    /// Drawn as the shelves draw a book: its cover when Open Library has one,
    /// else the app's typeset stand-in.
    var cover: Book {
        Book(
            id: "goodreads-\(key)",
            title: title,
            authors: authors,
            format: format,
            media: media,
            language: language,
            coverURL: coverURL,
            status: .toRead
        )
    }

    /// The record it would complete, as the "same book?" sheet shows it.
    var heldCover: Book? {
        guard let heldBookId, let heldTitle else { return nil }
        return Book(id: heldBookId, title: heldTitle, authors: authors, coverURL: heldCoverURL, status: .toRead)
    }

    /// Under its cover, how it lands: "Lu", "En cours", "Envie"…
    func caption(toRead: GoodreadsChoices.ToRead) -> String {
        switch status(toRead: toRead) {
        case .read: String(localized: "Lu")
        case .reading: String(localized: "En cours")
        case .dropped: String(localized: "Abandonné")
        case .toRead: String(localized: "À lire")
        case nil: String(localized: "Envie")
        }
    }
}

/// What a Goodreads export holds, against the library.
struct GoodreadsPreview: Sendable, Hashable {
    let rows: [GoodreadsRow]
    let readCount: Int
    let readingCount: Int
    let toReadCount: Int
    let droppedCount: Int
    let ratedCount: Int
    let datedCount: Int
    let reviewedCount: Int

    var newRows: [GoodreadsRow] { rows.filter { $0.verdict == .new } }
    var heldRows: [GoodreadsRow] { rows.filter { $0.verdict == .held } }
    var uncertainRows: [GoodreadsRow] { rows.filter { $0.verdict == .uncertain } }
}

/// What the reader decides before the import.
struct GoodreadsChoices: Sendable, Hashable {
    enum ToRead: String, Sendable, Hashable, CaseIterable {
        case wishlist
        case pile
    }

    /// The rows ticked: every new and held row at first; an uncertain one only
    /// once the reader answered it.
    var keys: Set<String>
    var toRead: ToRead = .wishlist
    var keepRatings = true
    var keepDates = true
    var keepReviews = true
    /// Uncertain rows the reader said are the book they already hold.
    var sameBooks: Set<String> = []

    /// Every new and held row, the uncertain left for the reader.
    init(preview: GoodreadsPreview) {
        keys = Set(preview.rows.filter { $0.verdict != .uncertain }.map(\.key))
    }

    /// How many rows an import would write.
    func importedCount(in preview: GoodreadsPreview) -> Int {
        preview.rows.filter { keys.contains($0.key) && $0.verdict != .held && !sameBooks.contains($0.key) }.count
    }
}

/// What an import wrote.
struct GoodreadsImportOutcome: Sendable, Hashable {
    let imported: Int
    let completed: Int
    let wished: Int
    let pendingCovers: Int
}

/// The reader's last import, for the settings page.
struct GoodreadsImportSummary: Sendable, Hashable {
    let importedAt: Date
    let imported: Int
    let completed: Int
    let wished: Int
    let pendingCovers: Int
    let withoutCover: Int
}

/// Why a file could not be read.
enum GoodreadsFileError: Error, Equatable {
    /// Not a Goodreads library export.
    case notGoodreads
    /// A Goodreads export with no book.
    case empty
    /// The file could not be opened or read as text.
    case unreadable
}

/// Where the reader exports the file, opened in Safari.
enum GoodreadsLinks {
    static let export = URL(string: "https://www.goodreads.com/review/import")!
}

/// A file handed to the app, to import.
struct GoodreadsFile: Identifiable, Hashable {
    let url: URL
    var id: URL { url }
}
