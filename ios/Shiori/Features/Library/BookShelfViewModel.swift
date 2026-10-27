import Foundation
import SwiftUI

/// Owns one shelf of the Library tab opened from its rail — "Récemment", the
/// pile, the books read, the favourites, the books given up on, every book —
/// loaded by pages, with its pills: the statuses over "Récemment", by date or
/// by genre over the books read and the favourites, the formats elsewhere.
@MainActor
@Observable
final class BookShelfViewModel {
    init(
        client: LibraryClient,
        shelf: BookShelf,
        view: ShelvesView = ShelvesView(),
        status: ReadingStatus? = nil,
        formats: [BookFormat] = [],
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.client = client
        self.now = now
        query = ShelfQuery(shelf: shelf, view: view, status: status)
        self.formats = formats
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
    /// The formats the shelf holds, kept from its first page: the pills. A
    /// shelf opened under a format already chosen is handed the opener's,
    /// since its pages hold that format alone.
    private(set) var formats: [BookFormat] = []
    /// How the books read and the favourites are cut: by date, or by genre.
    private(set) var grouping: ShelfGrouping = .date

    private var loaded = false
    private var generation = 0
    private var reloadTask: Task<Void, Never>?

    var shelf: BookShelf { query.shelf }

    /// "Récemment" shows six months, the rest of the library is a tap away
    /// in "Tous les livres".
    private static let recentMonths = 6
    /// Never fewer than the rail it was opened from drew, the server's
    /// `RAIL_LIMIT`: a format whose last book is older would open empty.
    private static let recentFloor = 20

    private var pageSize: Int { shelf == .all ? 140 : 60 }
    private var prefetchThreshold: Int { shelf == .all ? 42 : 12 }

    /// The pills over the grid: the statuses over "Récemment", the groupings
    /// over the books read and the favourites — whose formats the Library tab
    /// already chooses above them — otherwise the formats, shown only when
    /// there are two to choose from.
    var statusPills: [ReadingStatus] {
        shelf == .recent ? [.toRead, .reading, .read] : []
    }

    var groupingPills: [ShelfGrouping] {
        Self.groupedShelves.contains(shelf) ? ShelfGrouping.allCases : []
    }

    var shownFormats: [BookFormat] {
        shelf != .recent && !Self.groupedShelves.contains(shelf) && formats.count > 1 ? formats : []
    }

    private static let groupedShelves: Set<BookShelf> = [.read, .loved]

    /// By genre, every page is loaded: a genre's heading must not grow, nor a
    /// new one appear above, as the grid scrolls.
    private var loadsWholeShelf: Bool { grouping == .genre }

    /// The books cut under the shelf's headings.
    var sections: [ListSection<Book>] {
        let today = now()
        if grouping == .genre { return ListSection.byGenre(books) }
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

    /// The books already shown are only cut again; by genre, the pages not
    /// yet loaded are fetched behind them rather than emptying the grid.
    func select(grouping: ShelfGrouping) {
        guard self.grouping != grouping else { return }
        self.grouping = grouping
        guard grouping == .genre, hasMore else { return }
        reloadTask?.cancel()
        reloadTask = Task { await load() }
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
        let wanted = loadsWholeShelf ? Int.max : keepingDepth ? max(books.count, pageSize) : pageSize
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

    /// "Coups de cœur" as a message, every page of it, not only the ones
    /// scrolled to. Nil when the server failed, which the page then says.
    func shareMessage() async -> String? {
        do {
            var all: [Book] = []
            var more = true
            while more {
                let page = try await client.shelf(query, 200, all.last?.id)
                all += page.books
                more = page.hasMore && !page.books.isEmpty
            }
            return LovedShareMessage.text(books: all, series: lovedSeries)
        } catch {
            guard !isCancellation(error) else { return nil }
            errorMessage = reportError(error)
            return nil
        }
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore, let last = books.last else { return }
        let requested = generation
        isLoadingMore = true
        loadMoreFailed = false
        do {
            let page = try await client.shelf(query, pageSize, last.id)
            guard requested == generation else { return }
            let kept = withinShelf(page.books, below: books.count)
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

    /// "Récemment" stops six months back, past the books its rail drew.
    /// `shown` is how many rows the grid already holds above `fetched`.
    private func withinShelf(_ fetched: [Book], below shown: Int = 0) -> [Book] {
        guard shelf == .recent,
              let limit = Calendar.current.date(byAdding: .month, value: -Self.recentMonths, to: now())
        else { return fetched }
        return fetched.enumerated()
            .filter { index, book in shown + index < Self.recentFloor || (book.shelvedAt ?? .distantPast) >= limit }
            .map(\.element)
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
