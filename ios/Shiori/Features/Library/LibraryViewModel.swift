import Foundation

/// The three ways the Library tab looks at the shelf, switched from the
/// toolbar as Vinarium switches its wine list: everything, the favourites, or
/// the rated books best first. The Series tab offers the first two.
enum LibraryMode: String, CaseIterable, Identifiable {
    case all, favorites, rated
    var id: String { rawValue }

    /// The views the Series tab shares: sagas are hearted as books are, but
    /// the tab has no rating order of its own.
    static let seriesViews: [LibraryMode] = [.all, .favorites]

    var label: String {
        switch self {
        case .all: String(localized: "Tout")
        case .favorites: String(localized: "Favoris")
        case .rated: String(localized: "Notés")
        }
    }

    var icon: String {
        switch self {
        case .all: "books.vertical"
        case .favorites: "heart.fill"
        case .rated: "star.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .all: String(localized: "Par date")
        case .favorites: String(localized: "Vos coups de cœur")
        case .rated: String(localized: "Par note")
        }
    }
}

/// A view of the Library tab another screen asks it to open on.
struct LibraryRequest: Equatable {
    var mode: LibraryMode = .all
    var status: ReadingStatus?
}

/// Owns the library list: what is on screen, how it is arranged, and the one
/// in-flight load. Kept on the main actor because every property it exposes is
/// read by a view.
///
/// It opens on the list it closed on: its `SnapshotCache` hands back the last
/// visit's books from disk before a byte is asked of the network, so a
/// relaunch shows the library straight away and refreshes it underneath, under
/// a spinner row leading the list rather than a loader taking the screen. Every
/// view and filter keeps its own snapshot, so switching between them never
/// empties the list either.
@MainActor
@Observable
final class LibraryViewModel {
    init() {
        books = cache(for: mode, statusFilter).read() ?? []
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

    /// Each view's first page on disk, one file per view and filter, so that
    /// switching between them shows the rows of the last visit at once under
    /// the refresh spinner rather than an empty list reloading. Bump the
    /// version whenever `Book` changes shape.
    private func cache(for mode: LibraryMode, _ status: ReadingStatus?) -> SnapshotCache<[Book]> {
        SnapshotCache("library-\(mode.rawValue)-\(status?.rawValue ?? "all")", version: 4)
    }

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

    /// The rows cut into month headings, newest first, on the date the
    /// server shelved each book on — or, in the rated view, into one heading
    /// per number of stars, best first.
    var sections: [MonthSection<Book>] {
        mode == .rated
            ? MonthSection.cutByStars(books, on: \.shownRating)
            : MonthSection.cut(books, on: \.shelvedAt)
    }

    /// Opens the view another screen asks for, as the dashboard does: the
    /// rated books behind the rating tile, the pile behind its tile, the
    /// favourites and the dropped books behind theirs, the whole shelf behind
    /// the genre bar. A status filter left from an earlier visit is replaced,
    /// since it would hide half of what was asked for.
    func show(_ request: LibraryRequest) {
        statusFilter = request.status
        mode = request.mode
    }

    /// Reloads the first page for a new view or filter, cancelling a reload
    /// still in flight. The rows go at once: the old view's books under the new
    /// view's headings would be wrong for as long as the request takes.
    private func scheduleReload() {
        reloadTask?.cancel()
        generation += 1
        // The new view's rows from its last visit, when there were any: shown at
        // once and brought up to date under the spinner, as on launch.
        books = cache(for: mode, statusFilter).read() ?? []
        hasMore = false
        loaded = false
        refreshFailed = false
        isRefreshing = !books.isEmpty
        reloadTask = Task {
            await load()
            guard isRefreshing, !Task.isCancelled else { return }
            isRefreshing = false
            refreshFailed = !loaded
        }
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
            let cache = cache(for: mode, statusFilter)
            let fetched = page.books
            Task.detached { cache.write(fetched) }
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
    /// whole library. A change to what places the book — its status, which
    /// moves the date it is shelved on, or its heart, which the favourites view
    /// filters on — moves it, so that case falls back to a reload rather than
    /// leaving a row out of place.
    func apply(_ book: Book) async {
        guard let current = books.first(where: { $0.id == book.id }) else { return }
        let moved = current.status != book.status
            || current.favorite != book.favorite
        if moved {
            await load()
            return
        }
        // The detail screen's record does not carry the date the list files it
        // under; it has not moved, so the row keeps its own.
        var updated = book
        updated.shelvedAt = current.shelvedAt
        books = books.map { $0.id == book.id ? updated : $0 }
    }

    func remove(id: String) {
        books.removeAll { $0.id == id }
    }
}
