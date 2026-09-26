import Foundation
import SwiftUI

/// The two ways the Authors shelf lists its rows, switched from the toolbar as
/// the Books and Series shelves switch theirs: by name, as a contact list with
/// its alphabet down the side, or the loved authors first.
enum AuthorListOrder: String, CaseIterable, Identifiable {
    case name, loved
    var id: String { rawValue }

    var label: String {
        switch self {
        case .name: String(localized: "Alphabétique")
        case .loved: String(localized: "Favoris")
        }
    }

    var icon: String {
        switch self {
        case .name: "textformat"
        case .loved: "heart.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .name: String(localized: "Par nom")
        case .loved: String(localized: "Vos coups de cœur d'abord")
        }
    }
}

/// Owns the Authors shelf: the authors the reader holds books of, in the order
/// the toolbar asks, and the one in-flight load. The shelf opens on the rows it last
/// showed: a `SnapshotCache` hands them back from disk before a byte is asked
/// of the network, and the fetch brings them up to date silently underneath.
@MainActor
@Observable
final class AuthorListViewModel {
    init() {
        authors = Self.cache(for: .name).read() ?? []
    }

    /// How the rows are listed. By name, every author is loaded at once: the
    /// alphabet down the side must reach Z without waiting for a page.
    private(set) var order: AuthorListOrder = .name

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

    /// The authors on disk, one snapshot per order. Bump the version whenever
    /// `FollowedAuthor` changes shape.
    private var cache: SnapshotCache<[FollowedAuthor]> { Self.cache(for: order) }

    private static func cache(for order: AuthorListOrder) -> SnapshotCache<[FollowedAuthor]> {
        switch order {
        case .name: SnapshotCache("authors-by-name", version: 5)
        case .loved: SnapshotCache("authors-all", version: 5)
        }
    }

    /// Lists the rows the other way: last session's snapshot of that order at
    /// once, when the disk has one, brought up to date underneath.
    func show(_ order: AuthorListOrder) async {
        guard order != self.order else { return }
        self.order = order
        generation += 1
        authors = cache.read() ?? []
        hasMore = false
        loaded = false
        isLoading = false
        errorMessage = nil
        await loadOnAppear()
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
        let wanted = order == .name
            ? Int.max
            : keepingDepth ? max(authors.count, pageSize) : pageSize
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
                    limit: min(wanted - fetched.count, maxPageSize), offset: fetched.count,
                    order: order
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
            // By name the whole list is kept, as the whole list is drawn.
            let cache = cache
            let snapshot = order == .name ? fetched : Array(fetched.prefix(pageSize))
            Task.detached { cache.write(snapshot) }
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
                limit: pageSize, offset: authors.count, order: order
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
