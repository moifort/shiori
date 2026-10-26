import Foundation

/// What the Library tab's entry screen is narrowed to: a format pill, and on a
/// genre page its genre and one of its subgenres. Every shelf it opens keeps
/// the same view.
struct ShelvesView: Hashable, Codable, Sendable {
    var format: BookFormat?
    var genre: BookGenre?
    var subgenre: String?

    /// The name of the view's snapshot on disk.
    var cacheKey: String {
        [format?.rawValue ?? "all", genre?.rawValue ?? "any", subgenre ?? "any"].joined(separator: "-")
    }
}

/// The Library tab's entry screen as the server drew it: the format pills, the
/// rails of books, the genre tiles and the series and authors rails. A rail
/// with nothing in it is not drawn.
struct LibraryShelves: Codable, Sendable {
    /// The formats the library holds — under a genre page, its books' — as the
    /// pills list them. One alone offers no pill.
    var formats: [BookFormat] = []
    var recent: [Book] = []
    var toRead: [Book] = []
    var readRecently: [Book] = []
    var favorites: [Book] = []
    /// A book of the view was given up on: the "Abandonnés" row.
    var hasDropped = false
    var genres: [GenreShelf] = []
    /// Under a genre page, the subgenres the reader used, the most used first.
    var subgenres: [String] = []
    var series: [FollowedSeries] = []
    var authors: [FollowedAuthor] = []

    /// Nothing at all in the view: the empty library.
    var isEmpty: Bool { recent.isEmpty }
}

/// A genre of the library, as a tile of "Par genre" draws it.
struct GenreShelf: Identifiable, Hashable, Codable, Sendable {
    let genre: BookGenre
    let count: Int
    /// The cover of the book of that genre shelved last that has one, tilted in
    /// the tile's corner.
    var coverURL: URL?
    var id: BookGenre { genre }
}

/// One of the Library tab's shelves of books, as its rail and its own page
/// draw it.
enum BookShelf: String, Hashable, Codable, Sendable, Identifiable {
    case recent, toRead, read, loved, dropped, all
    var id: String { rawValue }

    var title: String {
        switch self {
        case .recent: String(localized: "Récemment")
        case .toRead: String(localized: "Pile à lire")
        case .read: String(localized: "Lus récemment")
        case .loved: String(localized: "Coups de cœur")
        case .dropped: String(localized: "Abandonnés")
        case .all: String(localized: "Tous les livres")
        }
    }

    /// The status the server narrows the shelf to, if any.
    var status: ReadingStatus? {
        switch self {
        case .toRead: .toRead
        case .read: .read
        case .dropped: .dropped
        case .recent, .loved, .all: nil
        }
    }

    /// The line each poster of the shelf's page carries.
    var context: PosterLabel.Context {
        switch self {
        case .recent: .journal
        case .toRead: .pile
        case .read: .read
        case .loved: .lovedByAuthor
        case .dropped: .dropped
        case .all: .recent
        }
    }
}

/// What a page of one shelf asks the server for: the shelf, the view it was
/// opened in, and the status pill of "Récemment".
struct ShelfQuery: Hashable, Sendable {
    var shelf: BookShelf
    var view = ShelvesView()
    /// "Ajoutés", "En cours", "Terminés" over "Récemment": one status.
    var status: ReadingStatus?

    var serverStatus: ReadingStatus? { status ?? shelf.status }
    var favorite: Bool { shelf == .loved }
    /// "Coups de cœur" draws a hearted saga as one card above its books.
    var excludeLovedSeries: Bool { shelf == .loved }
}
