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
}

/// The title being listened to, as the player draws it: what the list it was
/// started from already knew, so the accessory shows it before the licence is in.
struct ListeningTitle: Hashable, Sendable, Identifiable {
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
        guard let asin = book.audibleAsin else { return nil }
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

extension Book {
    /// The ASIN of an audiobook imported from Audible. The server hands its
    /// recording page out as `https://www.audible.{store}/pd/{asin}`, and only
    /// while the account is linked — exactly when it can be played.
    var audibleAsin: String? {
        guard format == .audiobook, let url = audibleURL else { return nil }
        let asin = url.lastPathComponent
        return asin.count == 10 && asin.allSatisfy({ $0.isLetter || $0.isNumber }) ? asin : nil
    }
}
