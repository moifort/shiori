import Foundation

/// Owns the library list: what is on screen, which shelf is filtered, and the
/// one in-flight load. Kept on the main actor because every property it exposes
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

    /// The whole library on disk. Bump the version whenever `LibrarySection`
    /// or `Book` changes shape.
    private let cache = SnapshotCache<[LibrarySection]>("library", version: 1)

    /// `nil` shows the whole library. The filter is applied server-side, before
    /// grouping, so a filtered saga loses its heading rather than showing an
    /// empty one.
    var filter: ReadingStatus? {
        didSet { if filter != oldValue { Task { await load() } } }
    }

    var isEmpty: Bool { sections.isEmpty && !isLoading && errorMessage == nil }

    /// How many books are on screen, across every section — what the empty and
    /// filtered states phrase themselves against.
    var bookCount: Int { sections.reduce(0) { $0 + $1.books.count } }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await LibraryAPI.library(status: filter)
            sections = fetched
            loaded = true
            // Only the whole library is what the next launch opens on: a
            // filtered shelf is a state the reader asked for this once.
            if filter == nil {
                let cache = cache
                Task.detached { cache.write(fetched) }
            }
        } catch {
            // The list keeps whatever it was showing: replacing a good library
            // with an empty one because a refresh failed reads as data loss.
            errorMessage = reportError(error)
        }
        isLoading = false
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
    /// whole library. A status change can move a book out of the current filter,
    /// so that case falls back to a reload rather than leaving a stale row.
    func apply(_ book: Book) async {
        if let filter, book.status != filter {
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
