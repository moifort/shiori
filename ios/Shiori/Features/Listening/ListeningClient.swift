import Foundation

/// What the player asks of the server.
struct ListeningClient: Sendable {
    /// A download licence: the title is kept on the iPhone as it plays.
    var start: @Sendable (_ asin: String) async throws -> Playback
    /// A content key the iPhone may keep.
    var contentKey: @Sendable (_ asin: String, _ spc: Data) async throws -> Data
    var savePosition: @Sendable (_ asin: String, _ contentReference: String, _ position: TimeInterval) async throws -> Void
    /// The audiobooks to play once this one ends, in order: the Audible titles
    /// under way, the last one started first, then the pile, the last one
    /// shelved first, this one aside. The player plays the first; the queue
    /// shows them all, so what it lists is what follows.
    var queue: @Sendable (_ after: String) async throws -> [ListeningQueueEntry]
}

extension ListeningClient {
    static let live = ListeningClient(
        start: { try await ListeningAPI.start(asin: $0, offline: true) },
        contentKey: { try await ListeningAPI.contentKey(asin: $0, request: $1, offline: true) },
        savePosition: { try await ListeningAPI.savePosition(asin: $0, contentReference: $1, at: $2) },
        queue: { asin in
            // The home's "En cours", the last one started first, then its pile,
            // the last one shelved first.
            let dashboard = try await HomeAPI.dashboard()
            var seen: Set<String> = [asin]
            return (dashboard.reading + dashboard.toRead)
                .compactMap(ListeningQueueEntry.init(book:))
                .filter { seen.insert($0.id).inserted }
        }
    )

    /// Answers a licence with no stream behind it: enough for previews, where
    /// nothing plays.
    static let preview = ListeningClient(
        start: { _ in .preview },
        contentKey: { _, _ in Data() },
        savePosition: { _, _, _ in },
        queue: { _ in ListeningQueueEntry.previews }
    )
}
