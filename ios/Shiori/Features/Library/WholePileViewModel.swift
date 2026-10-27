import Foundation
import SwiftUI

/// Owns "Toute la pile": every book of the pile in the view it was opened
/// from, cut by date, format or genre. The pile is loaded whole — a few
/// hundred books at most — so a section never grows as the list scrolls.
@MainActor
@Observable
final class WholePileViewModel {
    init(client: LibraryClient, view: ShelvesView = ShelvesView(), now: @escaping @Sendable () -> Date = { .now }) {
        self.client = client
        self.now = now
        query = ShelfQuery(shelf: .toRead, view: view)
    }

    private let client: LibraryClient
    private let now: @Sendable () -> Date
    private let query: ShelfQuery

    private(set) var books: [Book] = []
    private(set) var grouping: PileGrouping = .date
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private var loaded = false
    private var generation = 0

    /// The largest page the server serves.
    private static let pageSize = 200

    var sections: [ListSection<Book>] {
        WholePile.sections(books, by: grouping, now: now())
    }

    func label(of book: Book) -> PosterLabel {
        WholePile.label(of: book, by: grouping, now: now())
    }

    func select(grouping: PileGrouping) {
        withAnimation(.smooth) { self.grouping = grouping }
    }

    func loadOnAppear() async {
        guard !loaded, !isLoading else { return }
        await load()
    }

    /// Loads every page of the pile. A failure over books already on screen
    /// says nothing: they stay as they were, and a pull tries again.
    func load() async {
        generation += 1
        let requested = generation
        isLoading = true
        errorMessage = nil
        do {
            var fetched: [Book] = []
            var more = true
            while more {
                let page = try await client.shelf(query, Self.pageSize, fetched.last?.id)
                guard requested == generation else { return }
                fetched += page.books
                more = page.hasMore && !page.books.isEmpty
            }
            withAnimation(books.isEmpty ? nil : .smooth) { books = fetched }
            loaded = true
            CoverImages.prefetch(fetched.compactMap(\.coverURL))
        } catch {
            guard requested == generation else { return }
            isLoading = false
            guard !isCancellation(error) else { return }
            errorMessage = reportError(error)
            return
        }
        isLoading = false
    }
}
