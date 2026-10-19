import Foundation

/// The reader's whole library as the search reads it, kept on disk so the
/// search answers at once from the second opening on. One copy for the app:
/// the Home and Library tabs open the same search on the same index.
///
/// Brought up to date when the search opens, if it is more than an hour old
/// or anything in the library changed since. Patching one entry per change
/// was weighed and rejected: a deleted book or a renamed saga leaves nothing
/// to patch from, and a whole reload is cheap and always right.
@MainActor
@Observable
final class LibrarySearchIndex {
    static let shared = LibrarySearchIndex(client: .live)

    /// How long an index is trusted without asking the server again.
    static let freshFor: TimeInterval = 60 * 60

    struct Stored: Codable, Sendable {
        let books: [Book]
        let fetchedAt: Date
    }

    private(set) var entries: [SearchEntry] = []
    /// Something to search: the disk or the server has answered once.
    private(set) var isReady = false
    /// The first load, with nothing on disk to answer from, failed.
    private(set) var failed = false

    private let client: LibrarySearchClient
    private let cache: SnapshotCache<Stored>?
    private let now: @Sendable () -> Date
    private var fetchedAt: Date?
    private var stale = false
    private var refreshing: Task<Void, Never>?
    /// Bumped by `forget`: an answer for the account signed out is dropped.
    private var generation = 0

    /// - Parameter caching: off in tests and previews, which must neither read
    ///   nor leave an index on disk.
    init(client: LibrarySearchClient, caching: Bool = true, now: @escaping @Sendable () -> Date = { Date() }) {
        self.client = client
        cache = caching ? SnapshotCache("library-search", version: 1) : nil
        self.now = now
        Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .shioriDataDidChange) {
                self?.stale = true
            }
        }
    }

    /// Answer from disk when nothing is loaded yet. Fast: the screen calls it
    /// before drawing its first results.
    func loadFromDisk() async {
        guard !isReady, let cache else { return }
        let stored = await Task.detached { cache.read() }.value
        guard let stored, !isReady else { return }
        await take(stored.books, fetchedAt: stored.fetchedAt)
    }

    /// Ask the server when there is nothing to search, when the index is old,
    /// or when the library changed since. Without anything to search, the
    /// screen shows a loader while this runs; otherwise it runs underneath.
    func refreshIfNeeded() async {
        let old = fetchedAt.map { now().timeIntervalSince($0) > Self.freshFor } ?? true
        guard !isReady || stale || old else { return }
        if let refreshing { return await refreshing.value }
        let task = Task { await refresh() }
        refreshing = task
        await task.value
        refreshing = nil
    }

    /// Mark the index out of date: the next opening fetches it again.
    func markStale() {
        stale = true
    }

    /// Whoever signs in next must not search this account's books.
    func forget() {
        refreshing?.cancel()
        generation += 1
        entries = []
        isReady = false
        failed = false
        fetchedAt = nil
        stale = false
    }

    private func refresh() async {
        stale = false
        let asked = generation
        do {
            let books = try await client.index()
            guard asked == generation else { return }
            let fetched = now()
            await take(books, fetchedAt: fetched)
            failed = false
            cache?.write(Stored(books: books, fetchedAt: fetched))
        } catch {
            guard asked == generation else { return }
            // An index on disk keeps answering; only a first load has
            // nothing to show but the error.
            stale = true
            if !isReady { failed = true }
        }
    }

    /// Normalizing thousands of titles is kept off the main thread.
    private func take(_ books: [Book], fetchedAt: Date) async {
        let built = await Task.detached { books.map(SearchEntry.init) }.value
        entries = built
        self.fetchedAt = fetchedAt
        isReady = true
    }
}
