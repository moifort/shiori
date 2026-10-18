import Foundation

/// Everything the authors' screens ask of the server, as closures: `.live`
/// goes through `AuthorsAPI` and its neighbours, a test builds the one it needs.
struct AuthorsClient: Sendable {
    /// An author's page; nil when the reader no longer holds a book of theirs,
    /// unless `offered` names them.
    var page: @Sendable (_ key: String, _ offered: String?) async throws -> AuthorPage?
    /// The page once the AI has built the catalogue of an author nobody described.
    var catalogue: @Sendable (_ key: String, _ offered: String?) async throws -> AuthorPage?
    /// What the author announced or brought out lately, in each format.
    var releases: @Sendable (_ key: String) async throws -> [ReleaseFormat: AuthorReleases]
    /// True when the catalogue was rebuilt.
    var refresh: @Sendable (_ key: String) async throws -> Bool
    var stopAwaiting: @Sendable (_ editionId: String) async throws -> Void
    /// "Look the book up, then add it".
    var addBook: @Sendable (BookDraft, BookAddition.LookUp?) async throws -> Book
    /// One page of the Authors shelf after the given cursor, in that order.
    var list: @Sendable (_ limit: Int, _ after: String?, AuthorListOrder)
        async throws -> CursorPage<FollowedAuthor>
}

extension AuthorsClient {
    static let live = AuthorsClient(
        page: { try await AuthorsAPI.page(key: $0, offered: $1) },
        catalogue: { try await AuthorsAPI.page(key: $0, offered: $1, waitForCatalogue: true) },
        releases: { try await DiscoverAPI.authorReleases(key: $0) },
        refresh: { try await AuthorsAPI.refresh(key: $0) },
        stopAwaiting: { try await AwaitedAPI.stop(id: $0) },
        addBook: { try await BookAddition.add($0, lookingUp: $1, source: .author) },
        list: { try await AuthorsAPI.myAuthorsPage(limit: $0, after: $1, order: $2) }
    )
}
