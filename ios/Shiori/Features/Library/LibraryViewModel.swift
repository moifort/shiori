import Foundation

/// Owns the library list: what is on screen and the one in-flight load. Kept on the main actor because every property it exposes
/// is read by a view.
///
/// It opens on the list it closed on: its `SnapshotCache` hands back the last
/// visit's sections from disk before a byte is asked of the network, so a
/// relaunch shows the library straight away and refreshes it underneath, under
/// a spinner row leading the list rather than a loader taking the screen.
@MainActor
@Observable
final class LibraryViewModel {
    init() {
        sections = cache.read() ?? []
    }

    private(set) var sections: [LibrarySection] = []
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

    /// The first page on disk. Bump the version whenever `LibrarySection`
    /// or `Book` changes shape.
    private let cache = SnapshotCache<[LibrarySection]>("library", version: 1)

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

    var isEmpty: Bool { sections.isEmpty && !isLoading && errorMessage == nil }

    func load() async {
        generation += 1
        let requested = generation
        isLoading = true
        errorMessage = nil
        isLoadingMore = false
        loadMoreFailed = false
        do {
            let page = try await LibraryAPI.libraryPage(limit: pageSize, after: nil)
            guard requested == generation else { return }
            let fetched = page.sections
            sections = fetched
            hasMore = page.hasMore
            loaded = true
            let cache = cache
            Task.detached { cache.write(fetched) }
        } catch {
            // The list keeps whatever it was showing: replacing a good library
            // with an empty one because a refresh failed reads as data loss.
            errorMessage = reportError(error)
        }
        isLoading = false
    }

    /// Loads the next page and stitches it onto the rows already loaded: a saga
    /// cut across two pages comes back under the same heading, and its second
    /// half joins the first rather than opening a second section.
    func loadMore() async {
        guard hasMore, !isLoadingMore, let last = sections.last?.books.last else { return }
        let requested = generation
        isLoadingMore = true
        loadMoreFailed = false
        do {
            let page = try await LibraryAPI.libraryPage(limit: pageSize, after: last.id)
            guard requested == generation else { return }
            var stitched = sections
            for section in page.sections {
                if let index = stitched.indices.last, stitched[index].continues(section) {
                    stitched[index] = LibrarySection(
                        seriesId: section.seriesId,
                        seriesName: section.seriesName,
                        language: section.language,
                        opinion: section.opinion,
                        books: stitched[index].books + section.books
                    )
                } else {
                    stitched.append(section)
                }
            }
            sections = stitched
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
        let ids = sections.flatMap { $0.books.map(\.id) }
        guard let index = ids.firstIndex(of: bookId) else { return }
        if ids.count - index <= prefetchThreshold {
            Task { await loadMore() }
        }
    }

    /// The tab appeared: a list still showing last session's snapshot refreshes
    /// it under the leading spinner, anything else loads as it always did.
    func loadOnAppear() async {
        if !loaded, !sections.isEmpty {
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

    /// Applies a book the detail screen just changed, without refetching the
    /// whole library. A status change moves the book to another tier, so that
    /// case falls back to a reload rather than leaving a row out of place.
    func apply(_ book: Book) async {
        let current = sections.lazy.flatMap(\.books).first { $0.id == book.id }
        if current?.status != book.status {
            await load()
            return
        }
        sections = sections.map { section in
            guard section.books.contains(where: { $0.id == book.id }) else { return section }
            return LibrarySection(
                seriesId: section.seriesId,
                seriesName: section.seriesName,
                language: section.language,
                opinion: section.opinion,
                books: section.books.map { $0.id == book.id ? book : $0 }
            )
        }
    }

    func remove(id: String) {
        sections = sections.compactMap { section in
            let kept = section.books.filter { $0.id != id }
            // A section whose last book was deleted must disappear with it,
            // otherwise the list keeps a heading over nothing.
            guard !kept.isEmpty else { return nil }
            return LibrarySection(
                seriesId: section.seriesId,
                seriesName: section.seriesName,
                language: section.language,
                opinion: section.opinion,
                books: kept
            )
        }
    }
}
