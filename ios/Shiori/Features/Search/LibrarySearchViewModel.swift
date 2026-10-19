import Foundation

/// What the search screen shows, as the reader types: results from the index
/// on the phone at every keystroke, covers asked for the rows drawn once the
/// typing pauses.
@MainActor
@Observable
final class LibrarySearchViewModel {
    /// Covers asked for at once, at most: the server refuses more.
    static let coverBatch = 50

    init(
        index: LibrarySearchIndex,
        client: LibrarySearchClient,
        recents: RecentSearches = RecentSearches(),
        viewed: RecentlyViewed = RecentlyViewed(),
        coverDelay: Duration = .milliseconds(300)
    ) {
        self.index = index
        self.client = client
        self.recents = recents
        self.viewed = viewed
        self.coverDelay = coverDelay
        recentSearches = recents.all
    }

    private let index: LibrarySearchIndex
    private let client: LibrarySearchClient
    private let recents: RecentSearches
    private let viewed: RecentlyViewed
    private let coverDelay: Duration

    var query = "" {
        didSet {
            guard oldValue != query else { return }
            recompute()
        }
    }
    var filter = SearchFilter() {
        didSet {
            guard oldValue != filter else { return }
            recompute()
        }
    }

    private(set) var results = SearchResults.empty
    private(set) var recentSearches: [String]
    /// The books opened last, from anywhere in the app, as the index knows them.
    private(set) var recentlyViewed: [Book] = []
    /// Covers fetched for this screen, by book id: a signature lasts the hour.
    private(set) var covers: [String: URL] = [:]
    private var asked: Set<String> = []
    private var coverTask: Task<Void, Never>?

    /// No index to search yet: the loader shows.
    var isPreparing: Bool { !index.isReady && !index.failed }
    var failed: Bool { !index.isReady && index.failed }

    /// The query has words, or a filter lists without one.
    var isSearching: Bool { !SearchText.normalized(query).isEmpty || filter.isActive }

    /// Results from disk first, then from the server when the disk was empty or
    /// out of date.
    func appear() async {
        await index.loadFromDisk()
        recompute()
        await index.refreshIfNeeded()
        recompute()
    }

    func retry() async {
        await index.refreshIfNeeded()
        recompute()
    }

    func toggleFavorites() {
        filter.favorites.toggle()
    }

    /// One status at a time: choosing the one already on clears it.
    func select(_ status: ReadingStatus) {
        filter.status = filter.status == status ? nil : status
    }

    func clearFilter() {
        filter = SearchFilter()
    }

    func useRecent(_ recent: String) {
        query = recent
    }

    func clearRecentSearches() {
        recents.clear()
        recentSearches = []
    }

    /// A book page was closed: the one just opened leads the list.
    func refreshViewed() {
        recompute()
    }

    /// A result was opened from the current query: it becomes a recent search.
    func opened() {
        recents.remember(query)
        recentSearches = recents.all
    }

    private func recompute() {
        results = LibrarySearchMatcher.results(for: query, in: index.entries, filter: filter)
        let byId = Dictionary(index.entries.map { ($0.id, $0.book) }, uniquingKeysWith: { first, _ in first })
        recentlyViewed = viewed.ids.compactMap { byId[$0] }
        scheduleCovers()
    }

    /// The covers of the rows on top, once the typing pauses.
    private func scheduleCovers() {
        coverTask?.cancel()
        let shown = recentlyViewed + results.series.compactMap(\.books.first) + results.books
        let missing = Array(shown.map(\.id).filter { !asked.contains($0) }.uniqued().prefix(Self.coverBatch))
        guard !missing.isEmpty else { return }
        coverTask = Task { [client, coverDelay] in
            try? await Task.sleep(for: coverDelay)
            guard !Task.isCancelled else { return }
            asked.formUnion(missing)
            do {
                let fetched = try await client.covers(missing)
                covers.merge(fetched) { _, new in new }
            } catch {
                // A placeholder stays; the next query asks again.
                asked.subtract(missing)
            }
        }
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen: Set<Element> = []
        return filter { seen.insert($0).inserted }
    }
}
