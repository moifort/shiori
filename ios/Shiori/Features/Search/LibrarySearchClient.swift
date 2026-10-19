import Foundation

/// Everything the search asks of the server, as closures: `.live` goes through
/// `SearchAPI`, a test or a preview builds the one it needs.
struct LibrarySearchClient: Sendable {
    var index: @Sendable () async throws -> [Book]
    var covers: @Sendable (_ ids: [String]) async throws -> [String: URL]
}

extension LibrarySearchClient {
    static let live = LibrarySearchClient(
        index: { try await SearchAPI.index() },
        covers: { try await SearchAPI.covers(ids: $0) }
    )

}
