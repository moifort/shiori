#if DEBUG
import Foundation

/// The showcase library, for the search's previews and tests: Dungeon Crawler
/// Carl among others, covers included.
enum SearchFixtures {
    static var library: [Book] { Showcase.shelved }

    /// An index already loaded, as from disk, without touching the disk.
    @MainActor
    static func readyIndex(_ books: [Book] = library) async -> LibrarySearchIndex {
        let index = LibrarySearchIndex(client: .answering(books), caching: false)
        await index.refreshIfNeeded()
        return index
    }
}

extension LibrarySearchClient {
    /// Answers with the books given, their covers included, at once.
    static func answering(_ books: [Book]) -> LibrarySearchClient {
        LibrarySearchClient(
            index: { books.map { book in var bare = book; bare.coverURL = nil; return bare } },
            covers: { ids in
                let wanted = Set(ids)
                return Dictionary(uniqueKeysWithValues: books.compactMap { book in
                    wanted.contains(book.id) ? book.coverURL.map { (book.id, $0) } : nil
                })
            }
        )
    }

    static let preview = answering(SearchFixtures.library)
}
#endif
