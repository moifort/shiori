import Foundation

/// Everything the Library tab asks of the server, as closures: `.live` goes
/// through `LibraryAPI` and `AwaitedAPI`, a test builds the one it needs.
struct LibraryClient: Sendable {
    /// One page of the shelf after the given book, in the server's order.
    var page: @Sendable (LibraryMode, LibraryFilter?, _ limit: Int, _ after: String?) async throws -> LibraryPageResult
    var awaited: @Sendable (ReleaseFormat) async throws -> [AwaitedEdition]
}

extension LibraryClient {
    static let live = LibraryClient(
        page: { try await LibraryAPI.libraryPage(mode: $0, filter: $1, limit: $2, after: $3) },
        awaited: { try await AwaitedAPI.awaited(format: $0) }
    )
}
