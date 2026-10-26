import Foundation
import SwiftUI

/// Owns one shelf of the Library tab opened from its rail — "Récemment", the
/// pile, the books read, the favourites, the books given up on, every book —
/// loaded by pages, with its pills: the formats, or over "Récemment" the
/// statuses.
@MainActor
@Observable
final class BookShelfViewModel {
    init(
        client: LibraryClient,
        shelf: BookShelf,
        view: ShelvesView = ShelvesView(),
        status: ReadingStatus? = nil,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.client = client
        self.now = now
        query = ShelfQuery(shelf: shelf, view: view, status: status)
        formatPills = view.format == nil
    }

    private let client: LibraryClient
    private let now: @Sendable () -> Date

    private(set) var query: ShelfQuery
    private(set) var books: [Book] = []
    /// On "Coups de cœur", the hearted sagas, drawn as cards above the books.
    private(set) var lovedSeries: [FollowedSeries] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var hasMore = false
    private(set) var isLoadingMore = false
    private(set) var loadMoreFailed = false
    /// The formats the shelf holds, kept from its first page: the pills.
    private(set) var formats: [BookFormat] = []
    /// A shelf opened under a format already chosen offers no format pills.
    private let formatPills: Bool

    private var loaded = false
    private var generation = 0
    private var reloadTask: Task<Void, Never>?

    var shelf: BookShelf { query.shelf }

    /// "Récemment" shows six months, the rest of the library is a tap away
    /// in "Tous les livres".
    private static let recentMonths = 6

    private var pageSize: Int { shelf == .all ? 140 : 60 }
    private var prefetchThreshold: Int { shelf == .all ? 42 : 12 }

    /// The pills over the grid: the statuses over "Récemment", otherwise the
    /// formats, shown only when there are two to choose from.
    var statusPills: [ReadingStatus] {
        shelf == .recent ? [.toRead, .reading, .read] : []
    }

    var shownFormats: [BookFormat] {
        formatPills && shelf != .recent && formats.count > 1 ? formats : []
    }

    /// The books cut under the shelf's headings.
    var sections: [ListSection<Book>] {
        let today = now()
        switch shelf {
        case .recent, .read:
            return ListSection.byPeriod(books, on: \.shelvedAt, now: today)
        case .loved:
            return ListSection.byYear(books, on: \.shelvedAt)
        case .all:
            return ListSection.byMonth(books, on: \.shelvedAt)
        case .toRead, .dropped:
            return books.isEmpty ? [] : [ListSection(id: "all", title: "", rows: books)]
        }
    }

    func select(status: ReadingStatus?) {
        guard query.status != status else { return }
        query.status = status
        scheduleReload()
    }

    func select(format: BookFormat?) {
        guard query.view.format != format else { return }
        query.view.format = format
        scheduleReload()
    }

    private func scheduleReload() {
        reloadTask?.cancel()
        generation += 1
        books = []
        lovedSeries = []
        hasMore = false
        loaded = false
        reloadTask = Task { await load() }
    }

    func loadOnAppear() async {
        guard !loaded, !isLoading else { return }
        await load()
    }

    /// Loads the first page, or as many rows as are shown when
    /// `keepingDepth`: an edit made far down must not cut the grid back.
    func load(keepingDepth: Bool = false) async {
        generation += 1
        let requested = generation
        let wanted = keepingDepth ? max(books.count, pageSize) : pageSize
        isLoading = true
        errorMessage = nil
        loadMoreFailed = false
        do {
            let client = client, view = query.view, wantsSeries = shelf == .loved
            async let sagas: [FollowedSeries] = wantsSeries ? client.lovedSeries(view) : []
            var fetched: [Book] = []
            var more = true
            while more, fetched.count < wanted {
                let page = try await client.shelf(query, min(wanted - fetched.count, 200), fetched.last?.id)
                guard requested == generation else { return }
                fetched += page.books
                more = page.hasMore && !page.books.isEmpty
            }
            let kept = withinShelf(fetched)
            let loved = try await sagas
            guard requested == generation else { return }
            withAnimation(books.isEmpty ? nil : .smooth) {
                books = kept
                lovedSeries = loved
                hasMore = more && kept.count == fetched.count
            }
            if formats.isEmpty, query.view.format == nil {
                // The hearted sagas count too, whatever page is loaded.
                let held = fetched + loved.flatMap(\.volumes)
                formats = BookFormat.allCases.filter { format in held.contains { $0.format == format } }
            }
            loaded = true
            CoverImages.prefetch(kept.compactMap(\.coverURL))
        } catch {
            guard requested == generation else { return }
            isLoading = false
            guard !isCancellation(error) else { return }
            errorMessage = reportError(error)
            return
        }
        isLoading = false
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore, let last = books.last else { return }
        let requested = generation
        isLoadingMore = true
        loadMoreFailed = false
        do {
            let page = try await client.shelf(query, pageSize, last.id)
            guard requested == generation else { return }
            let kept = withinShelf(page.books)
            books += kept
            hasMore = page.hasMore && kept.count == page.books.count
            for format in BookFormat.allCases where !formats.contains(format) && kept.contains(where: { $0.format == format }) && query.view.format == nil {
                formats.append(format)
            }
            CoverImages.prefetch(kept.compactMap(\.coverURL))
        } catch is CancellationError {
            return
        } catch {
            guard requested == generation else { return }
            loadMoreFailed = true
            errorMessage = reportError(error)
        }
        isLoadingMore = false
    }

    func prefetchIfNeeded(for bookId: String) {
        guard hasMore, !isLoadingMore,
              let index = books.firstIndex(where: { $0.id == bookId }),
              books.count - index <= prefetchThreshold else { return }
        Task { await loadMore() }
    }

    /// "Récemment" stops six months back.
    private func withinShelf(_ fetched: [Book]) -> [Book] {
        guard shelf == .recent,
              let limit = Calendar.current.date(byAdding: .month, value: -Self.recentMonths, to: now())
        else { return fetched }
        return fetched.filter { ($0.shelvedAt ?? .distantPast) >= limit }
    }

    /// Puts back a book its page just changed, or drops it from a shelf it no
    /// longer belongs to.
    func apply(_ book: Book) {
        guard let index = books.firstIndex(where: { $0.id == book.id }) else { return }
        var updated = book
        updated.shelvedAt = updated.shelvedAt ?? books[index].shelvedAt
        let belongs = (query.serverStatus == nil || updated.status == query.serverStatus)
            && (!query.favorite || updated.favorite)
        if belongs { books[index] = updated } else { books.remove(at: index) }
    }

    func remove(id: String) {
        books.removeAll { $0.id == id }
    }
}
