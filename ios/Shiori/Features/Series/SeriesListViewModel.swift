import Foundation

/// Owns the Series tab: the sagas the reader follows and the one in-flight
/// load. It opens on the rows it closed on: its `SnapshotCache` hands back
/// the last visit's sagas from disk before a byte is asked of the network,
/// and the first fetch runs under a spinner row rather than behind a loader.
@MainActor
@Observable
final class SeriesListViewModel {
    init() {
        followed = cache.read() ?? []
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

    /// The followed sagas on disk. Bump the version whenever `FollowedSeries`
    /// changes shape.
    private let cache = SnapshotCache<[FollowedSeries]>("series", version: 1)

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await SeriesAPI.mySeries()
            followed = fetched
            loaded = true
            let cache = cache
            Task.detached { cache.write(fetched) }
        } catch {
            errorMessage = reportError(error)
        }
        isLoading = false
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
