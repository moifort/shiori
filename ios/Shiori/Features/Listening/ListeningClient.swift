import Foundation

/// What the player asks of the server.
struct ListeningClient: Sendable {
    var start: @Sendable (_ asin: String) async throws -> Playback
    var contentKey: @Sendable (_ asin: String, _ spc: Data) async throws -> Data
    var savePosition: @Sendable (_ asin: String, _ contentReference: String, _ position: TimeInterval) async throws -> Void
}

extension ListeningClient {
    static let live = ListeningClient(
        start: { try await ListeningAPI.start(asin: $0) },
        contentKey: { try await ListeningAPI.contentKey(asin: $0, request: $1) },
        savePosition: { try await ListeningAPI.savePosition(asin: $0, contentReference: $1, at: $2) }
    )

    /// Answers a licence with no stream behind it: enough for previews, where
    /// nothing plays.
    static let preview = ListeningClient(
        start: { _ in .preview },
        contentKey: { _, _ in Data() },
        savePosition: { _, _, _ in }
    )
}
