import Foundation

/// What a friend did to a book that the feed tells.
enum FeedEventKind: String, Codable, Sendable {
    case started, finished, loved
}

/// One thing a friend did, as the feed draws a row.
struct FeedEvent: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let kind: FeedEventKind
    let at: Date
    let friendId: String
    let friendName: String
    let bookId: String
    let title: String
    let authors: [String]
    let format: BookFormat
    let coverURL: URL?
    /// Their stars, when they gave any.
    let rating: Double?
    /// How many of the reader's other friends picked up the same story lately.
    let alsoStartedBy: Int
    /// Whether the reader already holds the story.
    var inLibrary: Bool

    /// Drawn as the Books tab draws a book, the headphones on a recording.
    var cover: Book {
        Book(id: "feed-\(id)", title: title, authors: authors, format: format, coverURL: coverURL, status: .toRead)
    }
}

/// A recording's narrator lending their voice to a book: the row exists for
/// when the server tells it, and no source feeds it yet.
struct NarratorNews: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let narrator: String
    let title: String
    let coverURL: URL?
    let format: BookFormat

    var cover: Book {
        Book(id: "narrator-\(id)", title: title, authors: [], format: .audiobook, coverURL: coverURL, status: .toRead)
    }
}

/// Which of the reader's follows an upcoming release comes from.
enum ReleaseSource: String, Codable, Sendable {
    case saga, author, awaited
}

/// A book announced, as the calendar and the author card draw it.
struct UpcomingRelease: Identifiable, Hashable, Codable, Sendable {
    struct AuthorRef: Hashable, Codable, Sendable {
        let key: String
        let name: String
        let favorite: Bool
        let portraitURL: URL?
    }

    let id: String
    let source: ReleaseSource
    let format: BookFormat
    /// Nil on an announcement that names no title yet.
    let title: String?
    let authors: [String]
    /// `YYYY`, `YYYY-MM` or `YYYY-MM-DD`; nil when announced for a date nobody found.
    let date: String?
    let coverURL: URL?
    let seriesName: String?
    let volume: Int?
    let author: AuthorRef?
    let sagaRating: Double?
    let sagaFavorite: Bool

    var cover: Book {
        Book(
            id: "release-\(id)",
            title: title ?? "?",
            authors: authors,
            format: format,
            coverURL: coverURL,
            status: .toRead
        )
    }

    /// "Red Rising · Tome 6", empty outside a saga.
    var seriesLine: String? {
        guard let seriesName else { return nil }
        return volume.map { String(localized: "\(seriesName) · Tome \($0)") } ?? seriesName
    }

    /// Why the reader is told of it, under its title in the calendar.
    var reason: String {
        switch source {
        case .author:
            if let author, author.favorite { return String(localized: "Auteur favori · \(author.name)") }
            return authors.first ?? ""
        case .saga:
            if sagaFavorite { return String(localized: "Série en coup de cœur") }
            if let sagaRating, sagaRating > 0 {
                return String(localized: "Série notée \(Self.stars(sagaRating))")
            }
            return seriesName ?? ""
        case .awaited:
            return format == .audiobook
                ? String(localized: "Dans votre liste d'envie · audio")
                : String(localized: "Dans votre liste d'envie")
        }
    }

    /// Five glyphs, monochrome: "★★★★☆".
    static func stars(_ rating: Double) -> String {
        let filled = min(5, max(0, Int(rating.rounded())))
        return String(repeating: "★", count: filled) + String(repeating: "☆", count: 5 - filled)
    }
}

/// The formats the pills narrow the feed to: every one but the audiobook is a
/// printed object, so "Livres" is the books alone.
extension BookFormat {
    /// The pills' labels, plural: "Livres", "Livres audio", "BD".
    var pillLabel: String {
        switch self {
        case .book: String(localized: "Livres")
        case .audiobook: String(localized: "Livres audio")
        case .bandeDessinee: String(localized: "BD")
        case .comic: String(localized: "Comics")
        case .manga: String(localized: "Mangas")
        }
    }
}
