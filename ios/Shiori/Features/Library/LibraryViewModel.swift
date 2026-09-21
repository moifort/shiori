import Foundation

/// The three ways the Library tab looks at the shelf, switched from the
/// toolbar as Vinarium switches its wine list.
enum LibraryMode: String, CaseIterable, Identifiable {
    case all, genre, favorites
    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: String(localized: "Tout")
        case .genre: String(localized: "Genre")
        case .favorites: String(localized: "Favoris")
        }
    }

    var icon: String {
        switch self {
        case .all: "books.vertical"
        case .genre: "square.grid.2x2"
        case .favorites: "heart.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .all: String(localized: "Par statut de lecture")
        case .genre: String(localized: "Par genre")
        case .favorites: String(localized: "Vos coups de cœur")
        }
    }
}

/// One heading of the Library tab: a reading status, or a genre. Cut out of
/// the flat list the server ordered, wherever the key changes from one book to
/// the next — so a page that lands extends the last section rather than
/// opening a second one under the same heading.
struct LibraryShelf: Identifiable {
    enum Key: Equatable {
        case status(ReadingStatus)
        /// Nil for the books of no genre, which the server puts last.
        case genre(BookGenre?)
    }

    /// The position, not the key: the key is unique only as long as the server
    /// keeps its promise of one run per key, and a duplicate id is a list that
    /// draws the wrong rows.
    let id: Int
    let key: Key
    let books: [Book]

    var title: String {
        switch key {
        case .status(let status): status.shelfTitle
        case .genre(let genre): genre?.label ?? String(localized: "Sans genre")
        }
    }
}

/// Owns the library list: what is on screen, how it is arranged, and the one
/// in-flight load. Kept on the main actor because every property it exposes is
/// read by a view.
///
/// It opens on the list it closed on: its `SnapshotCache` hands back the last
/// visit's books from disk before a byte is asked of the network, so a
/// relaunch shows the library straight away and refreshes it underneath, under
/// a spinner row leading the list rather than a loader taking the screen. Only
/// the default view is cached — it is the one the tab opens on.
@MainActor
@Observable
final class LibraryViewModel {
    init() {
        books = cache.read() ?? []
    }

    private(set) var books: [Book] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    /// Any change of view or filter reloads the first page.
    var mode: LibraryMode = .all {
        didSet { if oldValue != mode { scheduleReload() } }
    }
    /// Narrows the list to one reading status; nil shows them all.
    var statusFilter: ReadingStatus? {
        didSet { if oldValue != statusFilter { scheduleReload() } }
    }

    /// The rows on screen are last session's and fresher ones are on their
    /// way. Never set by a pull-to-refresh, whose own control spins.
    private(set) var isRefreshing = false
    /// That refresh failed: the rows are the ones from last time, and the
    /// leading row offers to try again.
    private(set) var refreshFailed = false
    /// The server has answered at least once, so the rows are no longer the
    /// snapshot.
    private var loaded = false

    /// The default view's first page on disk. Bump the version whenever `Book`
    /// changes shape.
    private let cache = SnapshotCache<[Book]>("library", version: 2)

    /// More rows follow the ones on screen.
    private(set) var hasMore = false
    private(set) var isLoadingMore = false
    /// The last page failed: the sentinel turns into a retry button instead of
    /// a spinner that would keep turning forever without a new attempt.
    private(set) var loadMoreFailed = false

    /// Sixty rows fill several screens on the smallest phone: enough that the
    /// next page is fetched while the reader is still scrolling the first.
    private let pageSize = 60
    /// Well below the page size, otherwise the next page would load as soon as
    /// the first one is displayed.
    private let prefetchThreshold = 8
    /// Stale-result token: a page asked for before a reload must not be
    /// appended to the list that replaced it.
    private var generation = 0
    private var reloadTask: Task<Void, Never>?

    private var isDefaultView: Bool { mode == .all && statusFilter == nil }

    /// Whether the rows are already sectioned by status, in which case a row
    /// saying its own status would repeat its heading. Filtered to one status,
    /// every row has the same one and the filter already says which.
    var sectionsByStatus: Bool { mode != .genre || statusFilter != nil }

    /// The rows cut into headings wherever the key changes.
    var sections: [LibraryShelf] {
        var shelves: [LibraryShelf] = []
        var current: (key: LibraryShelf.Key, books: [Book])?
        for book in books {
            let key: LibraryShelf.Key = mode == .genre ? .genre(book.genre) : .status(book.status)
            if current?.key == key {
                current?.books.append(book)
            } else {
                if let current {
                    shelves.append(LibraryShelf(id: shelves.count, key: current.key, books: current.books))
                }
                current = (key, [book])
            }
        }
        if let current {
            shelves.append(LibraryShelf(id: shelves.count, key: current.key, books: current.books))
        }
        return shelves
    }

    /// Reloads the first page for a new view or filter, cancelling a reload
    /// still in flight. The rows go at once: the old view's books under the new
    /// view's headings would be wrong for as long as the request takes.
    private func scheduleReload() {
        reloadTask?.cancel()
        generation += 1
        books = []
        hasMore = false
        isRefreshing = false
        refreshFailed = false
        reloadTask = Task { await load() }
    }

    func load() async {
        generation += 1
        let requested = generation
        isLoading = true
        errorMessage = nil
        isLoadingMore = false
        loadMoreFailed = false
        do {
            let page = try await LibraryAPI.libraryPage(
                mode: mode, status: statusFilter, limit: pageSize, after: nil
            )
            guard requested == generation else { return }
            books = page.books
            hasMore = page.hasMore
            loaded = true
            if isDefaultView {
                let cache = cache
                let fetched = page.books
                Task.detached { cache.write(fetched) }
            }
        } catch is CancellationError {
            return
        } catch {
            guard requested == generation else { return }
            // The list keeps whatever it was showing: replacing a good library
            // with an empty one because a refresh failed reads as data loss.
            errorMessage = reportError(error)
        }
        isLoading = false
    }

    /// Loads the next page and appends it to the rows already loaded.
    func loadMore() async {
        guard hasMore, !isLoadingMore, let last = books.last else { return }
        let requested = generation
        isLoadingMore = true
        loadMoreFailed = false
        do {
            let page = try await LibraryAPI.libraryPage(
                mode: mode, status: statusFilter, limit: pageSize, after: last.id
            )
            guard requested == generation else { return }
            books += page.books
            hasMore = page.hasMore
        } catch is CancellationError {
            return
        } catch {
            guard requested == generation else { return }
            loadMoreFailed = true
            errorMessage = reportError(error)
        }
        isLoadingMore = false
    }

    /// Starts the next page when a row close to the end appears.
    func prefetchIfNeeded(for bookId: String) {
        guard hasMore, !isLoadingMore else { return }
        guard let index = books.firstIndex(where: { $0.id == bookId }) else { return }
        if books.count - index <= prefetchThreshold {
            Task { await loadMore() }
        }
    }

    /// The tab appeared: a list still showing last session's snapshot refreshes
    /// it under the leading spinner, anything else loads as it always did.
    func loadOnAppear() async {
        if !loaded, !books.isEmpty {
            await refresh()
        } else {
            await load()
        }
    }

    /// Bring the rows on screen up to date without taking them away — and the
    /// retry when that failed.
    func refresh() async {
        isRefreshing = true
        refreshFailed = false
        await load()
        // A view or filter change took the list over meanwhile, and this
        // refresh no longer has anything to say.
        guard isRefreshing else { return }
        isRefreshing = false
        refreshFailed = !loaded
    }

    /// Applies a book the detail screen just changed, without refetching the
    /// whole library. A change to what places the book — its status, its
    /// genre, its heart — moves it, so that case falls back to a reload rather
    /// than leaving a row out of place. The reading dates only ever move with
    /// the status, and the rows do not carry them.
    func apply(_ book: Book) async {
        guard let current = books.first(where: { $0.id == book.id }) else { return }
        let moved = current.status != book.status
            || current.genre != book.genre
            || current.favorite != book.favorite
        if moved {
            await load()
            return
        }
        books = books.map { $0.id == book.id ? book : $0 }
    }

    func remove(id: String) {
        books.removeAll { $0.id == id }
    }
}
