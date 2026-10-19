import Foundation

/// The search, as the app talks to the server. Covers come apart from the
/// index: a signature lives an hour, the index lives on disk for days.
enum SearchAPI {
    /// Every book of the reader, covers left out.
    static func index() async throws -> [Book] {
        #if DEBUG
        if Showcase.isOn { return Showcase.shelved.map { book in var bare = book; bare.coverURL = nil; return bare } }
        #endif
        let data = try await GraphQLHelpers.fetch(GraphQLClient.shared.apollo, query: ShioriGraphQL.LibrarySearchIndexQuery())
        return data.librarySearchIndex.map { $0.fragments.bookSummary.asBook }
    }

    /// The covers of the books named, by id. A book without one is absent.
    static func covers(ids: [String]) async throws -> [String: URL] {
        #if DEBUG
        if Showcase.isOn {
            let wanted = Set(ids)
            return Dictionary(uniqueKeysWithValues: Showcase.shelved.compactMap { book in
                wanted.contains(book.id) ? book.coverURL.map { (book.id, $0) } : nil
            })
        }
        #endif
        let data = try await GraphQLHelpers.fetch(GraphQLClient.shared.apollo, query: ShioriGraphQL.BookCoversQuery(ids: ids))
        return Dictionary(
            data.bookCovers.compactMap { cover in cover.coverUrl.flatMap(URL.init(string:)).map { (cover.id, $0) } },
            uniquingKeysWith: { first, _ in first }
        )
    }
}
