import Foundation

/// Owns the Series tab: the sagas the reader follows, how they are narrowed —
/// the Library tab's two views and a state filter — and the
/// one in-flight load. Every view opens on the rows it last showed: a
/// `SnapshotCache` per view hands them back from disk before a byte is asked
/// of the network, and the fetch runs under a spinner row rather than behind
/// a loader.
@MainActor
@Observable
final class SeriesListViewModel {
    init() {
        followed = cache(for: mode, stateFilter).read() ?? []
    }

    /// Any change of view or filter reloads the first page.
    var mode: LibraryMode = .all {
        didSet { if oldValue != mode { scheduleReload() } }
    }
    /// Narrows the list to one state; nil shows them all.
    var stateFilter: SeriesState? {
        didSet { if oldValue != stateFilter { scheduleReload() } }
    }
    private var reloadTask: Task<Void, Never>?

    private(set) var followed: [FollowedSeries] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    /// The rows on screen are last session's and fresher ones are on their
    /// way. Never set by a pull-to-refresh, whose own control spins.
    private(set) var isRefreshing = false
    /// That refresh failed: the rows are the ones from last time, and the
    /// leading row offers to try again.
    private(set) var refreshFailed = false
    /// The server has answered at least once, so the rows are no longer the
    /// snapshot.
    private var loaded = false

    /// Each view's sagas on disk. Bump the version whenever `FollowedSeries`
    /// changes shape.
    private func cache(for mode: LibraryMode, _ state: SeriesState?) -> SnapshotCache<[FollowedSeries]> {
        SnapshotCache("series-\(mode.rawValue)-\(state?.rawValue ?? "all")", version: 6)
    }

    /// Switching view: the new view's rows from its last visit at once, brought
    /// up to date under the spinner.
    private func scheduleReload() {
        reloadTask?.cancel()
        generation += 1
        followed = cache(for: mode, stateFilter).read() ?? []
        hasMore = false
        loaded = false
        refreshFailed = false
        isRefreshing = !followed.isEmpty
        reloadTask = Task {
            await load()
            guard isRefreshing, !Task.isCancelled else { return }
            isRefreshing = false
            refreshFailed = !loaded
        }
    }

    /// More rows follow the ones on screen.
    private(set) var hasMore = false
    private(set) var isLoadingMore = false
    private(set) var loadMoreFailed = false

    private let pageSize = 40
    private let prefetchThreshold = 6
    private var generation = 0

    func load() async {
        generation += 1
        let requested = generation
        isLoading = true
        errorMessage = nil
        isLoadingMore = false
        loadMoreFailed = false
        do {
            let page = try await SeriesAPI.mySeriesPage(
                limit: pageSize, offset: 0, mode: mode, state: stateFilter
            )
            guard requested == generation else { return }
            let fetched = page.items
            followed = fetched
            hasMore = page.hasMore
            loaded = true
            let cache = cache(for: mode, stateFilter)
            Task.detached { cache.write(fetched) }
        } catch is CancellationError {
            return
        } catch {
            guard requested == generation else { return }
            errorMessage = reportError(error)
        }
        isLoading = false
    }

    /// Loads the next page and appends it to the rows already loaded.
    func loadMore() async {
        guard hasMore, !isLoadingMore else { return }
        let requested = generation
        isLoadingMore = true
        loadMoreFailed = false
        do {
            let page = try await SeriesAPI.mySeriesPage(
                limit: pageSize, offset: followed.count, mode: mode, state: stateFilter
            )
            guard requested == generation else { return }
            followed.append(contentsOf: page.items)
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
    func prefetchIfNeeded(for id: String) {
        guard hasMore, !isLoadingMore else { return }
        guard let index = followed.firstIndex(where: { $0.id == id }) else { return }
        if followed.count - index <= prefetchThreshold {
            Task { await loadMore() }
        }
    }

    /// The tab appeared: a list still showing last session's snapshot refreshes
    /// it under the leading spinner, anything else loads as it always did.
    func loadOnAppear() async {
        if !loaded, !followed.isEmpty {
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
        isRefreshing = false
        refreshFailed = !loaded
    }
}
