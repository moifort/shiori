import Foundation

/// What the player asks of the server.
struct ListeningClient: Sendable {
    var start: @Sendable (_ asin: String) async throws -> Playback
    var contentKey: @Sendable (_ asin: String, _ spc: Data) async throws -> Data
    var savePosition: @Sendable (_ asin: String, _ contentReference: String, _ position: TimeInterval) async throws -> Void
    /// The audiobook to play once this one ends: the Audible title the reader
    /// started most recently among those under way, this one aside.
    var nextInProgress: @Sendable (_ after: String) async throws -> ListeningTitle?
}

extension ListeningClient {
    static let live = ListeningClient(
        start: { try await ListeningAPI.start(asin: $0) },
        contentKey: { try await ListeningAPI.contentKey(asin: $0, request: $1) },
        savePosition: { try await ListeningAPI.savePosition(asin: $0, contentReference: $1, at: $2) },
        nextInProgress: { asin in
            // The home's "En cours", the last one started first.
            try await HomeAPI.dashboard().reading
                .compactMap(ListeningTitle.init(book:))
                .first { $0.asin != asin }
        }
    )

    /// Answers a licence with no stream behind it: enough for previews, where
    /// nothing plays.
    static let preview = ListeningClient(
        start: { _ in .preview },
        contentKey: { _, _ in Data() },
        savePosition: { _, _, _ in },
        nextInProgress: { _ in nil }
    )
}
