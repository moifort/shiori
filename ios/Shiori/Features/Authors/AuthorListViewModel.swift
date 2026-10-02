import Foundation
import SwiftUI

/// The ways the Authors shelf lists its rows, switched from the toolbar as
/// the Books and Series shelves switch theirs: by activity, as the Books and
/// Series shelves are ordered, cut into months; by name, as a contact list
/// with its alphabet down the side; or the loved authors first.
enum AuthorListOrder: String, CaseIterable, Identifiable {
    case recent, name, loved
    var id: String { rawValue }

    var label: String {
        switch self {
        case .name: String(localized: "Alphabétique")
        case .recent: String(localized: "Date")
        case .loved: String(localized: "Favoris")
        }
    }

    var icon: String {
        switch self {
        case .name: "textformat"
        case .recent: "clock"
        case .loved: "heart.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .name: String(localized: "Par nom")
        case .recent: String(localized: "Par date")
        case .loved: String(localized: "Vos coups de cœur d'abord")
        }
    }

    var graphQL: ShioriGraphQL.AuthorOrder {
        switch self {
        case .name: .name
        case .recent: .recent
        case .loved: .loved
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
    /// Opens by date, as the Books and Series shelves do.
    init() {
        authors = Self.cache(for: order).read() ?? []
    }

    /// How the rows are listed. By name, every author is loaded at once: the
    /// alphabet down the side must reach Z without waiting for a page.
    private(set) var order: AuthorListOrder = .recent

    private(set) var authors: [FollowedAuthor] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    /// The server has answered at least once, so the rows are no longer the
    /// snapshot.
    private var loaded = false

    /// The authors on disk, one snapshot per order. Bump the version whenever
    /// `FollowedAuthor` changes shape.
    private var cache: SnapshotCache<[FollowedAuthor]> { Self.cache(for: order) }

    private static func cache(for order: AuthorListOrder) -> SnapshotCache<[FollowedAuthor]> {
        switch order {
        case .name: SnapshotCache("authors-by-name", version: 6)
        case .recent: SnapshotCache("authors-by-activity", version: 6)
        case .loved: SnapshotCache("authors-all", version: 6)
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
    /// A failure over rows already on screen says nothing: they stay as they
    /// were, and a pull tries again.
    func load(keepingDepth: Bool = false) async {
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
                guard requested == generation else { return }
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
            // By name the whole list is kept, as the whole list is drawn.
            let cache = cache
            let snapshot = order == .name ? fetched : Array(fetched.prefix(pageSize))
            Task.detached { cache.write(snapshot) }
        } catch {
            guard requested == generation else { return }
            isLoading = false
            guard !isCancellation(error) else { return }
            errorMessage = reportError(error)
            return
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
        await load()
    }
}
