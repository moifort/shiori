import Foundation
import SwiftUI

/// Owns the Authors shelf: the authors the reader holds books of, the loved
/// ones first, everything or the favourites, and the one in-flight load. Every
/// view opens on the rows it last showed: a `SnapshotCache` per view hands them
/// back from disk before a byte is asked of the network, and the fetch brings
/// them up to date silently underneath.
@MainActor
@Observable
final class AuthorListViewModel {
    init() {
        authors = cache(for: mode).read() ?? []
    }

    /// A change of view reloads the first page.
    var mode: LibraryMode = .all {
        didSet { if oldValue != mode { scheduleReload() } }
    }
    private var reloadTask: Task<Void, Never>?

    private(set) var authors: [FollowedAuthor] = []
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

    /// Each view's authors on disk. Bump the version whenever `FollowedAuthor`
    /// changes shape.
    private func cache(for mode: LibraryMode) -> SnapshotCache<[FollowedAuthor]> {
        SnapshotCache("authors-\(mode.rawValue)", version: 1)
    }

    /// Switching view: the new view's rows from its last visit at once, brought
    /// up to date underneath.
    private func scheduleReload() {
        reloadTask?.cancel()
        generation += 1
        authors = cache(for: mode).read() ?? []
        hasMore = false
        loaded = false
        refreshFailed = false
        isRefreshing = !authors.isEmpty
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
        let wanted = keepingDepth ? max(authors.count, pageSize) : pageSize
        isLoading = true
        errorMessage = nil
        isLoadingMore = false
        loadMoreFailed = false
        do {
            // The server caps a page, so a deep list comes back in several,
            // swapped in at once so the rows never shrink in between.
            var fetched: [FollowedAuthor] = []
            var more = true
            while more, fetched.count < wanted {
                let page = try await AuthorsAPI.myAuthorsPage(
                    limit: min(wanted - fetched.count, maxPageSize), offset: fetched.count, mode: mode
                )
                guard requested == generation else { return false }
                fetched += page.items
                more = page.hasMore && !page.items.isEmpty
            }
            // Over rows already on screen, the new ones slide into place and
            // push the others aside rather than the whole list redrawing at
            // once: a heart given moves its author up the list, visibly.
            withAnimation(authors.isEmpty ? nil : .smooth) {
                authors = fetched
                hasMore = more
            }
            loaded = true
            // Fresh rows: whatever an earlier refresh said is no longer true.
            refreshFailed = false
            let cache = cache(for: mode)
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
            let page = try await AuthorsAPI.myAuthorsPage(
                limit: pageSize, offset: authors.count, mode: mode
            )
            guard requested == generation else { return }
            authors.append(contentsOf: page.items)
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
        guard let index = authors.firstIndex(where: { $0.id == id }) else { return }
        if authors.count - index <= prefetchThreshold {
            Task { await loadMore() }
        }
    }

    /// The shelf appeared: a list still showing last session's snapshot
    /// refreshes it, one never loaded loads. A list the server already answered
    /// asks nothing: every write posts the change notice this shelf listens to.
    func loadOnAppear() async {
        guard !loaded, !isLoading else { return }
        if !authors.isEmpty {
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
