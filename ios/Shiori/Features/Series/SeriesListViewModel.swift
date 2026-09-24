import Foundation

/// A view of the Series tab another screen asks it to open on: the dashboard's
/// "series in progress" card opens it on the sagas in progress.
struct SeriesRequest: Equatable {
    var mode: LibraryMode = .all
    var state: SeriesState?
}

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

    /// Opens the view another screen asks for. A state filter left from an
    /// earlier visit is replaced, since it would hide what was asked for.
    func show(_ request: SeriesRequest) {
        stateFilter = request.state
        mode = request.mode
    }

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
        SnapshotCache("series-\(mode.rawValue)-\(state?.rawValue ?? "all")", version: 7)
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
            let failed = await load()
            guard isRefreshing, !Task.isCancelled else { return }
            isRefreshing = false
            refreshFailed = failed
        }
    }

    /// More rows follow the ones on screen.
    private(set) var hasMore = false
    private(set) var isLoadingMore = false
    private(set) var loadMoreFailed = false

    private let pageSize = 40
    /// The most rows the server hands back in one page.
    private let maxPageSize = 200
    private let prefetchThreshold = 6
    private var generation = 0

    /// Loads the first page, or as many rows as the list already shows when
    /// `keepingDepth` is set: a reload after an edit far down the list must
    /// not cut it back to the first page and throw the reader to the top.
    ///
    /// Says whether it failed. A load a newer one took over, or one called off,
    /// did not: the rows are whatever the newer one brings.
    @discardableResult
    func load(keepingDepth: Bool = false) async -> Bool {
        generation += 1
        let requested = generation
        let wanted = keepingDepth ? max(followed.count, pageSize) : pageSize
        isLoading = true
        errorMessage = nil
        isLoadingMore = false
        loadMoreFailed = false
        do {
            // The server caps a page, so a deep list comes back in several,
            // swapped in at once so the rows never shrink in between.
            var fetched: [FollowedSeries] = []
            var more = true
            while more, fetched.count < wanted {
                let page = try await SeriesAPI.mySeriesPage(
                    limit: min(wanted - fetched.count, maxPageSize), offset: fetched.count,
                    mode: mode, state: stateFilter
                )
                guard requested == generation else { return false }
                fetched += page.items
                more = page.hasMore && !page.items.isEmpty
            }
            followed = fetched
            hasMore = more
            loaded = true
            // Fresh rows: whatever an earlier refresh said is no longer true.
            refreshFailed = false
            let cache = cache(for: mode, stateFilter)
            let firstPage = Array(fetched.prefix(pageSize))
            Task.detached { cache.write(firstPage) }
        } catch {
            guard requested == generation else { return false }
            isLoading = false
            guard !isCancellation(error) else { return false }
            errorMessage = reportError(error)
            return true
        }
        isLoading = false
        return false
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

    /// Whether a book is one of the volumes the list shows for this edition.
    func holds(bookId: String, in destination: SeriesDestination) -> Bool {
        let id = FollowedSeries.id(seriesId: destination.seriesId, language: destination.language)
        return followed.first { $0.id == id }?.volumes.contains { $0.id == bookId } == true
    }

    /// Asks the server again for one saga the reader just changed and puts its
    /// rows back, rather than reloading every page to find them: the edition
    /// that was open, and every other edition on screen, since the rating,
    /// the heart and the count of volumes belong to the saga. A row keeps its
    /// place unless the change moved it — a volume finished moves the saga's
    /// date — and leaves the list when the saga is gone or no longer matches
    /// the view. One shelved past the last loaded row waits for its page.
    ///
    /// A changed book that is no longer among the saga's volumes went to
    /// another saga, or away: that other row is not known here, so the list
    /// reloads whole, keeping the reader's place.
    func refreshRows(of destination: SeriesDestination, changedBooks: Set<String>) async {
        let requested = generation
        var languages = [destination.language]
        for row in followed where row.seriesId == destination.seriesId && !languages.contains(row.language) {
            languages.append(row.language)
        }
        var volumes: Set<String> = []
        do {
            for language in languages {
                let fresh = try await SeriesAPI.followedSeries(
                    seriesId: destination.seriesId, language: language
                )
                guard requested == generation else { return }
                place(fresh, as: FollowedSeries.id(seriesId: destination.seriesId, language: language))
                volumes.formUnion(fresh?.volumes.map(\.id) ?? [])
            }
        } catch is CancellationError {
            return
        } catch {
            guard requested == generation else { return }
            errorMessage = reportError(error)
            return
        }
        if !changedBooks.isSubset(of: volumes) {
            await load(keepingDepth: true)
        }
    }

    private func place(_ fresh: FollowedSeries?, as id: String) {
        followed.removeAll { $0.id == id }
        guard let fresh, belongs(fresh) else { return }
        let index = followed.firstIndex { Self.shelvesBefore(fresh, $0) } ?? followed.endIndex
        guard index < followed.endIndex || !hasMore else { return }
        followed.insert(fresh, at: index)
    }

    /// The server's filter: a saga of unknown state counts as complete, and one
    /// set aside shows under its own filter only.
    private func belongs(_ saga: FollowedSeries) -> Bool {
        if mode == .favorites, saga.opinion?.favorite != true { return false }
        let state = saga.state ?? .complete
        guard let stateFilter else { return state != .unfollowed }
        return state == stateFilter
    }

    /// The server's order: the most recently shelved saga first, then by name.
    private static func shelvesBefore(_ left: FollowedSeries, _ right: FollowedSeries) -> Bool {
        let leftDate = left.shelvedAt ?? .distantPast
        let rightDate = right.shelvedAt ?? .distantPast
        if leftDate != rightDate { return leftDate > rightDate }
        return left.name < right.name
    }

    /// The tab appeared: a list still showing last session's snapshot refreshes
    /// it under the leading spinner, one never loaded loads. A list the server
    /// already answered asks nothing: every write posts the change notice this
    /// tab listens to, so coming back to it only redrew the same rows at the
    /// cost of a request.
    func loadOnAppear() async {
        guard !loaded, !isLoading else { return }
        if !followed.isEmpty {
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
        let failed = await load()
        isRefreshing = false
        refreshFailed = failed
    }
}
