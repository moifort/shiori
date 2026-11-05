import Foundation

/// A book the reader does not hold and would like to: wished for from a
/// friend's shelf, a discovery, an award, an author's works or a scan. Never
/// on the shelf, counted or shared; it goes on its own once the library holds
/// the story.
struct Wish: Identifiable, Hashable, Codable, Sendable {
    /// Where the reader came across it.
    enum Origin: String, Codable, Sendable, Hashable {
        case friend, discovery, award, author, scan
    }

    let id: String
    let title: String
    let authors: [String]
    let format: BookFormat
    let language: BookLanguage?
    let seriesName: String?
    let volume: Int?
    let coverURL: URL?
    let isbn13: String?
    let origin: Origin
    /// The friend's first name, the award's: what the cover is labelled with.
    let originLabel: String?
    let friendId: String?
    let wishedAt: Date

    /// Under its cover: where it came from — the friend, "Découverte", the
    /// award, "Auteur", "Scan".
    var originCaption: String {
        switch origin {
        case .friend: originLabel ?? String(localized: "Un ami")
        case .discovery: String(localized: "Découverte")
        case .award: originLabel ?? String(localized: "Prix")
        case .author: String(localized: "Auteur")
        case .scan: String(localized: "Scan")
        }
    }

    /// Drawn as the shelves draw a book, the headphones on a recording's cover.
    var cover: Book {
        Book(
            id: "wish-\(id)",
            title: title,
            authors: authors,
            format: format,
            language: language,
            coverURL: coverURL,
            status: .toRead
        )
    }

    /// What putting it on the shelf sends: the facts it was wished with. The
    /// server finds its saga again from its title and author.
    func draft(status: ReadingStatus) -> BookDraft {
        var draft = BookDraft(title: title, authors: authors)
        draft.format = format
        if format == .audiobook { draft.media = [] }
        draft.language = language
        draft.isbn13 = isbn13
        draft.coverURL = coverURL
        draft.status = status
        return draft
    }
}

extension SnapshotCache where Value == Wishlist {
    /// The one wishlist snapshot, shared by the wishlist screen and the pile's
    /// rail: whichever loaded last leaves it for the other to open on. Bump
    /// the version whenever `Wishlist` changes shape.
    static var wishlist: SnapshotCache<Wishlist> { SnapshotCache("wishlist", version: 1) }
}

/// Everything the reader would like and does not hold: the books wished for
/// and the editions awaited, cut into the sections the list draws.
struct Wishlist: Codable, Sendable, Equatable {
    var wishes: [Wish] = []
    var awaited: [AwaitedEdition] = []

    var isEmpty: Bool { wishes.isEmpty && awaited.isEmpty }

    /// The editions announced for a known day still to come, the soonest first.
    var upcoming: [AwaitedEdition] {
        awaited
            .filter { $0.announcedDate != nil }
            .sorted { ($0.date ?? "") < ($1.date ?? "") }
    }

    /// The editions awaited that are out.
    var released: [AwaitedEdition] { awaited.filter { $0.state == .available } }

    /// The editions nobody announced yet, or announced with no day to come.
    var unannounced: [AwaitedEdition] {
        awaited.filter { $0.state != .available && $0.announcedDate == nil }
    }

    var fromFriends: [Wish] { wishes.filter { $0.origin == .friend } }

    var discovered: [Wish] { wishes.filter { [.discovery, .award, .author].contains($0.origin) } }

    var scanned: [Wish] { wishes.filter { $0.origin == .scan } }

    /// What can be had now, for the pile's rail: the editions out, then every
    /// book wished for.
    var availableNow: [Book] { released.map(\.cover) + wishes.map(\.cover) }
}

extension Wishlist {
    /// The pile's rail labels each book with where it came from.
    func caption(of book: Book) -> String {
        if let wish = wishes.first(where: { $0.cover.id == book.id }) { return wish.originCaption }
        return String(localized: "Guetté")
    }

    /// The wish a cover of the pile's rail stands for, if it is one.
    func wish(for book: Book) -> Wish? { wishes.first { $0.cover.id == book.id } }

    /// The edition a cover of the pile's rail stands for, if it is one.
    func edition(for book: Book) -> AwaitedEdition? { awaited.first { $0.cover.id == book.id } }
}
