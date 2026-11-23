import Foundation

/// A chapter of a recording, in playing order.
struct ListeningChapter: Hashable, Sendable, Codable {
    let title: String
    /// Seconds from the start of the recording.
    let start: TimeInterval
    let length: TimeInterval

    var end: TimeInterval { start + length }
}

/// What the player needs to play one Audible title, from a licence the server
/// asked Amazon for. The stream is FairPlay-encrypted HLS that AVFoundation
/// plays as it is; its key is traded through the server, which keeps the
/// device credentials.
struct Playback: Sendable {
    let asin: String
    /// Opaque, handed back with every saved position.
    let contentReference: String
    let streamURL: URL
    /// The FairPlay application certificate.
    let certificate: Data
    let duration: TimeInterval
    let chapters: [ListeningChapter]
    /// Where the reader stopped last, on any of their Audible players.
    let resumeAt: TimeInterval?
    /// When that position was saved.
    var resumeSavedAt: Date? = nil
}

/// The title being listened to, as the player draws it: what the list it was
/// started from already knew, so the accessory shows it before the licence is in.
struct ListeningTitle: Hashable, Sendable, Identifiable, Codable {
    let asin: String
    let title: String
    /// The series and the volume, "Les Cantos d'Hypérion · Tome 3", or the author.
    let subtitle: String?
    let coverURL: URL?
    /// The book in the library, to open its page from the player.
    var bookID: String?

    var id: String { asin }
}

extension ListeningTitle {
    /// The title an audiobook of the library plays, or nil when it has none:
    /// only a recording imported from a linked Audible account can be played.
    init?(book: Book) {
        guard book.format == .audiobook, let asin = book.audibleAsin else { return nil }
        let series = book.series.map { membership in
            membership.volume.map { "\(membership.name) · \(String(localized: "Tome \($0)"))" }
                ?? membership.name
        }
        self.init(
            asin: asin,
            title: book.title,
            subtitle: series ?? book.authors.first,
            coverURL: book.coverURL,
            bookID: book.id
        )
    }
}

/// One audiobook of the player's queue: what follows once the title playing
/// ends, and how far into it the reader already is.
struct ListeningQueueEntry: Hashable, Sendable, Identifiable {
    let title: ListeningTitle
    /// Whole percent heard, on a recording under way; nil on the pile.
    let heard: Int?

    var id: String { title.asin }
}

extension ListeningQueueEntry {
    init?(book: Book) {
        guard let title = ListeningTitle(book: book) else { return nil }
        self.init(title: title, heard: book.status == .reading ? book.listeningProgress : nil)
    }
}
