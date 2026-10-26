import Foundation

/// Everything the Library tab asks of the server, as closures: `.live` goes
/// through `LibraryAPI` and `AwaitedAPI`, a test builds the one it needs.
struct LibraryClient: Sendable {
    /// One page of the shelf after the given book, in the server's order.
    var page: @Sendable (LibraryMode, LibraryFilter?, _ limit: Int, _ after: String?) async throws -> LibraryPageResult
    var awaited: @Sendable (ReleaseFormat) async throws -> [AwaitedEdition]
    /// The entry screen in a view.
    var shelves: @Sendable (ShelvesView) async throws -> LibraryShelves = { _ in LibraryShelves() }
    /// One page of a shelf after the given book.
    var shelf: @Sendable (ShelfQuery, _ limit: Int, _ after: String?) async throws -> LibraryPageResult = { _, _, _ in
        LibraryPageResult(books: [], hasMore: false)
    }
    /// The long press on a cover.
    var setStatus: @Sendable (_ id: String, ReadingStatus) async throws -> Book = { _, _ in .preview }
    var setFavorite: @Sendable (_ id: String, Bool) async throws -> Book = { _, _ in .preview }
    var rate: @Sendable (_ id: String, _ stars: Double) async throws -> Book = { _, _ in .preview }
    var delete: @Sendable (_ id: String) async throws -> Void = { _ in }
}

extension LibraryClient {
    static let live = LibraryClient(
        page: { try await LibraryAPI.libraryPage(mode: $0, filter: $1, limit: $2, after: $3) },
        awaited: { try await AwaitedAPI.awaited(format: $0) },
        shelves: { try await LibraryAPI.shelves($0) },
        shelf: { try await LibraryAPI.shelfPage($0, limit: $1, after: $2) },
        setStatus: { try await BookAPI.setStatus(id: $0, status: $1) },
        setFavorite: { try await BookAPI.setFavorite(id: $0, favorite: $1) },
        rate: { try await BookAPI.rate(id: $0, stars: $1) },
        delete: { try await BookAPI.delete(id: $0) }
    )
}

#if DEBUG
extension LibraryClient {
    /// Answers from the App Store showcase and accepts every write.
    static let preview = LibraryClient(
        page: { mode, filter, limit, after in
            Showcase.libraryPage(mode: mode, filter: filter, limit: limit, after: after)
        },
        awaited: { _ in [] },
        shelves: { Showcase.libraryShelves(view: $0) },
        shelf: { Showcase.shelfPage($0, limit: $1, after: $2) }
    )
}
#endif
