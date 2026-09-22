import Foundation

@MainActor
@Observable
final class HomeViewModel {
    init() {
        dashboard = cache.read()
    }

    private(set) var dashboard: Dashboard?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    /// The figures on screen are last session's and fresher ones are on their
    /// way: a spinner leads the page. Never set by a pull-to-refresh, whose own
    /// control spins.
    private(set) var isRefreshing = false
    /// That refresh failed: the figures are the ones from last time, and the
    /// leading row offers to try again.
    private(set) var refreshFailed = false
    /// The server has answered at least once, so what is on screen is no
    /// longer the snapshot.
    private var loaded = false

    /// The last dashboard on disk. Bump the version whenever `Dashboard`
    /// changes shape.
    private let cache = SnapshotCache<Dashboard>("dashboard", version: 2)

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await HomeAPI.dashboard()
            dashboard = fetched
            loaded = true
            let cache = cache
            Task.detached { cache.write(fetched) }
        } catch {
            // The last dashboard stays on screen: blanking good figures because a
            // refresh failed reads as data loss.
            errorMessage = reportError(error)
        }
        isLoading = false
    }

    /// The tab appeared: a dashboard still showing last session's snapshot
    /// refreshes it under the leading spinner, anything else loads as it
    /// always did.
    func loadOnAppear() async {
        if !loaded, dashboard != nil {
            await refresh()
        } else {
            await load()
        }
    }

    /// Bring the snapshot on screen up to date without taking it away — and
    /// the retry when that failed.
    func refresh() async {
        isRefreshing = true
        refreshFailed = false
        await load()
        isRefreshing = false
        refreshFailed = !loaded
    }
}
