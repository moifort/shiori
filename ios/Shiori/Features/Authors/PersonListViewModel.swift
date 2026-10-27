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

/// A person a shelf list draws as a row: their face and name, then their
/// books as posters — an author, a narrator.
protocol ShelvedPerson: PortraitPerson, Codable, Sendable where ID == String {
    var books: [Book] { get }
}

extension FollowedAuthor: ShelvedPerson {}

typealias AuthorListViewModel = PersonListViewModel<FollowedAuthor>
typealias NarratorListViewModel = PersonListViewModel<FollowedNarrator>

extension PersonListViewModel where Person == FollowedAuthor {
    convenience init(client: AuthorsClient, caching: Bool = true) {
        self.init(cacheName: "authors", caching: caching, list: client.list)
    }
}

extension PersonListViewModel where Person == FollowedNarrator {
    convenience init(client: NarratorsClient, caching: Bool = true) {
        self.init(cacheName: "narrators", caching: caching, list: client.list)
    }
}

/// Owns a shelf of people — the Authors shelf, the narrators list: the people
/// the reader holds books of, in the order the pills ask, and the one in-flight
/// load. The shelf opens on the rows it last showed: a `SnapshotCache` hands
/// them back from disk before a byte is asked of the network, and the fetch
/// brings them up to date silently underneath.
@MainActor
@Observable
final class PersonListViewModel<Person: ShelvedPerson> {
    typealias List = @Sendable (_ limit: Int, _ after: String?, AuthorListOrder)
        async throws -> CursorPage<Person>

    /// Opens by date, as the Books and Series shelves do.
    /// - Parameters:
    ///   - cacheName: what the snapshots on disk are named after.
    ///   - caching: off in tests, which must neither read nor leave a
    ///     snapshot on disk.
    init(cacheName: String, caching: Bool = true, list: @escaping List) {
        self.list = list
        self.cacheName = cacheName
        self.caching = caching
        people = cache?.read() ?? []
    }

    private let list: List
    private let cacheName: String
    private let caching: Bool

    /// How the rows are listed. By name, everyone is loaded at once: the
    /// alphabet down the side must reach Z without waiting for a page.
    private(set) var order: AuthorListOrder = .recent

    private(set) var people: [Person] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    /// The server has answered at least once, so the rows are no longer the
    /// snapshot.
    private var loaded = false

    /// The rows on disk, one snapshot per order. Bump the version whenever
    /// `Person` changes shape.
    private var cache: SnapshotCache<[Person]>? {
        guard caching else { return nil }
        let suffix = switch order {
        case .name: "by-name"
        case .recent: "by-activity"
        case .loved: "all"
        }
        return SnapshotCache("\(cacheName)-\(suffix)", version: 7)
    }

    /// Lists the rows the other way: last session's snapshot of that order at
    /// once, when the disk has one, brought up to date underneath.
    func show(_ order: AuthorListOrder) async {
        guard order != self.order else { return }
        self.order = order
        generation += 1
        people = cache?.read() ?? []
        hasMore = false
        nextCursor = nil
        loaded = false
        isLoading = false
        errorMessage = nil
        await loadOnAppear()
    }

    /// More rows follow the ones on screen.
    private(set) var hasMore = false
    /// Where the server's next page starts: the last row it handed back.
    private var nextCursor: String?
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
            : keepingDepth ? max(people.count, pageSize) : pageSize
        isLoading = true
        errorMessage = nil
        isLoadingMore = false
        loadMoreFailed = false
        do {
            // The server caps a page, so a deep list comes back in several,
            // swapped in at once so the rows never shrink in between.
            var fetched: [Person] = []
            var more = true
            var cursor: String?
            while more, fetched.count < wanted {
                let page = try await list(min(wanted - fetched.count, maxPageSize), cursor, order)
                guard requested == generation else { return }
                fetched += page.items
                cursor = page.endCursor ?? cursor
                more = page.hasMore && !page.items.isEmpty
            }
            // Over rows already on screen, the new ones slide into place and
            // push the others aside rather than the whole list redrawing at
            // once: a heart given moves its person up the list, visibly.
            withAnimation(people.isEmpty ? nil : .smooth) {
                people = fetched
                hasMore = more
            }
            nextCursor = cursor
            loaded = true
            // By name the whole list is kept, as the whole list is drawn.
            if let cache {
                let snapshot = order == .name ? fetched : Array(fetched.prefix(pageSize))
                Task.detached { cache.write(snapshot) }
            }
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
            let page = try await list(pageSize, nextCursor, order)
            guard requested == generation else { return }
            people.append(contentsOf: page.items)
            nextCursor = page.endCursor ?? nextCursor
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
        guard let index = people.firstIndex(where: { $0.id == id }) else { return }
        if people.count - index <= prefetchThreshold {
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
