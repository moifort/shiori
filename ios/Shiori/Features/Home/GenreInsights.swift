import Foundation

/// What the reader's finished books say about their tastes, genre by genre: the
/// page the dashboard's genre card opens. Every figure is worked out by the
/// server; the app only draws it.
struct GenreInsights: Codable, Sendable {
    /// How many finished books carry one genre.
    struct Share: Identifiable, Hashable, Codable, Sendable {
        var id: BookGenre { genre }
        let genre: BookGenre
        let count: Int
    }

    /// How many finished books came in one format, and the genre the reader
    /// most often reads in it: fantasy heard, crime on paper.
    struct FormatShare: Identifiable, Hashable, Codable, Sendable {
        var id: BookFormat { format }
        let format: BookFormat
        let count: Int
        let topGenre: BookGenre?
    }

    /// One place on the taste map: a genre, or a subgenre that gathers enough
    /// rated books of its own, by how much it is read against how much it is
    /// liked. Only places with enough rated books to mean something are drawn.
    struct Taste: Identifiable, Hashable, Codable, Sendable {
        var id: String { "\(genre.rawValue)~\(subgenre ?? "")" }
        let genre: BookGenre
        /// Nil for the books of the genre that no subgenre took.
        var subgenre: String?
        let readCount: Int
        let averageRating: Double

        /// What the bubble is named: the subgenre as the reader wrote it, else
        /// the genre.
        var label: String { subgenre ?? genre.label }
    }

    /// The genre whose books run longest, in pages on average.
    struct LongestRecord: Hashable, Codable, Sendable {
        let genre: BookGenre
        let averagePages: Int
    }

    /// The genre read fastest, in days from the first page to the last.
    struct FastestRecord: Hashable, Codable, Sendable {
        let genre: BookGenre
        let averageDays: Int
    }

    /// The genre given up most often, out of the books of it ever started.
    struct DroppedRecord: Hashable, Codable, Sendable {
        let genre: BookGenre
        let droppedCount: Int
        let startedCount: Int
    }

    /// A genre the reader has never finished a book of, and how many of its
    /// books already wait on the pile.
    struct Unexplored: Identifiable, Hashable, Codable, Sendable {
        var id: BookGenre { genre }
        let genre: BookGenre
        let pileCount: Int
    }

    let readCount: Int
    /// Every genre read, the most read first.
    let shares: [Share]
    /// Every format read, the most read first.
    let formats: [FormatShare]
    let tastes: [Taste]
    /// The reader's average across every rated book: what splits the taste map
    /// between the genres liked more and the genres liked less.
    let averageRating: Double?
    /// The place read little and liked most, when one stands out.
    let gem: Taste?
    let longest: LongestRecord?
    let fastest: FastestRecord?
    let mostDropped: DroppedRecord?
    /// The genres of the closed list never read, those on the pile first.
    let unexplored: [Unexplored]
}

extension GenreInsights {
    static let preview = GenreInsights(
        readCount: 42,
        shares: [
            .init(genre: .fantasy, count: 14),
            .init(genre: .scienceFiction, count: 8),
            .init(genre: .crime, count: 6),
            .init(genre: .thriller, count: 4),
            .init(genre: .historicalFiction, count: 3),
            .init(genre: .essay, count: 3),
            .init(genre: .adventure, count: 2),
            .init(genre: .horror, count: 1),
            .init(genre: .literaryFiction, count: 1),
        ],
        formats: [
            .init(format: .book, count: 27, topGenre: .crime),
            .init(format: .audiobook, count: 9, topGenre: .fantasy),
            .init(format: .manga, count: 4, topGenre: .adventure),
            .init(format: .bandeDessinee, count: 2, topGenre: .historicalFiction),
        ],
        tastes: [
            .init(genre: .fantasy, readCount: 8, averageRating: 3.9),
            .init(genre: .fantasy, subgenre: "Dark fantasy", readCount: 6, averageRating: 4.5),
            .init(genre: .scienceFiction, subgenre: "Space opera", readCount: 5, averageRating: 4.4),
            .init(genre: .crime, readCount: 6, averageRating: 3.6),
            .init(genre: .thriller, readCount: 4, averageRating: 3.2),
            .init(genre: .historicalFiction, subgenre: "Uchronie", readCount: 3, averageRating: 4.8),
            .init(genre: .essay, readCount: 3, averageRating: 3.4),
        ],
        averageRating: 4.0,
        gem: .init(genre: .historicalFiction, subgenre: "Uchronie", readCount: 3, averageRating: 4.8),
        longest: .init(genre: .fantasy, averagePages: 612),
        fastest: .init(genre: .thriller, averageDays: 4),
        mostDropped: .init(genre: .essay, droppedCount: 3, startedCount: 7),
        unexplored: [
            .init(genre: .poetry, pileCount: 1),
            .init(genre: .travel, pileCount: 1),
            .init(genre: .romance, pileCount: 0),
            .init(genre: .humor, pileCount: 0),
            .init(genre: .drama, pileCount: 0),
            .init(genre: .biography, pileCount: 0),
            .init(genre: .history, pileCount: 0),
            .init(genre: .science, pileCount: 0),
            .init(genre: .selfHelp, pileCount: 0),
            .init(genre: .business, pileCount: 0),
            .init(genre: .art, pileCount: 0),
            .init(genre: .cooking, pileCount: 0),
        ]
    )

    /// A reader with a single book finished: too little for a radar, a map or
    /// a record, which the page leaves out rather than draws from one point.
    static let firstBook = GenreInsights(
        readCount: 1,
        shares: [.init(genre: .fantasy, count: 1)],
        formats: [.init(format: .book, count: 1, topGenre: .fantasy)],
        tastes: [],
        averageRating: 4,
        gem: nil,
        longest: nil,
        fastest: nil,
        mostDropped: nil,
        unexplored: BookGenre.allCases
            .filter { $0 != .fantasy && $0 != .other }
            .map { .init(genre: $0, pileCount: 0) }
    )
}
