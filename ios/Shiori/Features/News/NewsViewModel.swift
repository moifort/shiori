import Foundation
import Observation
import SwiftUI

/// The Actualités tab's state: the friends' feed page by page, the releases
/// "Sorti" and "À venir" are laid from, the tab shown and the pills and friend
/// that narrow them. The tab opens on what it last showed: a `SnapshotCache`
/// hands it back from disk before a byte is asked of the network, and the
/// answer slides in over it.
@MainActor @Observable
final class NewsViewModel {
    /// The page size of the feed: a few screens of rows.
    static let pageSize = 20

    private let client: NewsClient
    private let defaults: UserDefaults?
    private var generation = 0

    private(set) var events: [FeedEvent] = []
    private(set) var hasMore = false
    private var cursor: String?
    private(set) var releases: [UpcomingRelease] = []
    private(set) var yearReleases: [UpcomingRelease] = []
    private(set) var narratorNews: [NarratorNews] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?
    private(set) var pageFailed = false
    /// Books the reader just took, greyed out at once.
    private(set) var taken: Set<String> = []
    private(set) var alertsSilenced = false
    private(set) var isInviting = false
    /// The invitation to pass on, presented the moment it comes back.
    var invitation: FriendInvitation?

    var tab: NewsTab = .releases {
        didSet { if tab == .friends, oldValue != .friends { markFriendsSeen() } }
    }
    /// The pill chosen on Sorties; nil is "Tout".
    var format: BookFormat?
    /// The friend picked at the top of Amis; nil is everyone.
    var friendId: String?
    /// When the reader last opened Amis: the dot on the tab and the lit rings
    /// count from it.
    private(set) var friendsSeenAt: Date?
    /// The rings stay as they were when Amis opened, rather than going out
    /// under the reader's eyes.
    private var ringsSeenAt: Date?

    private static let friendsSeenKey = "news.friendsSeenAt"

    /// What the tab opens on: the feed's first page and everything around it.
    private struct Snapshot: Codable {
        let events: [FeedEvent]
        let releases: [UpcomingRelease]
        let yearReleases: [UpcomingRelease]
        let narratorNews: [NarratorNews]
    }

    /// The last news on disk. Bump the version whenever one of these types
    /// changes shape.
    private let cache: SnapshotCache<Snapshot>?

    /// - Parameter caching: off in tests, which must neither read nor leave
    ///   a snapshot on disk, nor the day Amis was last opened.
    init(client: NewsClient, caching: Bool = true) {
        self.client = client
        defaults = caching ? .standard : nil
        cache = caching ? SnapshotCache<Snapshot>("news", version: 2) : nil
        friendsSeenAt = defaults?.object(forKey: Self.friendsSeenKey) as? Date
        ringsSeenAt = friendsSeenAt
        if let snapshot = cache?.read() {
            events = snapshot.events
            releases = snapshot.releases
            yearReleases = snapshot.yearReleases
            narratorNews = snapshot.narratorNews
        }
    }

    // MARK: - Reading

    /// Every move, the books just taken marked as held.
    var shownEvents: [FeedEvent] {
        events.map { event in
            var shown = event
            if taken.contains(event.bookId) { shown.inLibrary = true }
            return shown
        }
    }

    var shownReleases: [UpcomingRelease] {
        releases.filter { format == nil || $0.format == format }
    }

    func released(now: Date = .now) -> [ReleasedItem] {
        NewsFeedLayout.released(releases: yearReleases, narrator: narratorNews, format: format, now: now)
    }

    func calendar(now: Date = .now) -> ReleaseCalendar {
        ReleaseCalendar(releases: shownReleases, now: now)
    }

    func friendSections(now: Date = .now) -> [FriendSection] {
        NewsFeedLayout.friendSections(events: shownEvents, friendId: friendId, now: now)
    }

    var stories: [FriendStory] {
        NewsFeedLayout.stories(events: events, seenAt: ringsSeenAt)
    }

    /// A friend moved since the reader last opened Amis.
    var friendsHaveNews: Bool {
        guard tab != .friends, let latest = events.map(\.at).max() else { return false }
        return friendsSeenAt.map { latest > $0 } ?? true
    }

    // MARK: - Loading

    func loadOnAppear() async {
        guard !hasLoaded else { return }
        await load()
    }

    /// The first page and the releases, asked together. Over rows already on
    /// screen a failure says nothing.
    func load() async {
        generation += 1
        let token = generation
        isLoading = !hasLoaded
        defer { if token == generation { isLoading = false } }
        async let page = capture { try await client.feed(nil, Self.pageSize) }
        async let upcoming = capture { try await client.upcoming() }
        async let narrated = capture { try await client.narratorNews() }
        async let released = capture { try await client.yearReleases() }
        let (first, dated, voices, year) = await (page, upcoming, narrated, released)
        guard token == generation else { return }
        // Over news already on screen, what changed slides into place rather
        // than the whole page redrawing at once.
        let isFilled = !events.isEmpty || !releases.isEmpty || !yearReleases.isEmpty
        withAnimation(isFilled ? .smooth : nil) {
            if case let .success(first) = first {
                events = first.items
                cursor = first.endCursor
                hasMore = first.hasMore
                errorMessage = nil
            }
            if case let .success(dated) = dated { releases = dated }
            if case let .success(voices) = voices { narratorNews = voices }
            if case let .success(year) = year { yearReleases = year }
        }
        if case let .failure(error) = first, !isCancellation(error) {
            if events.isEmpty { errorMessage = error.localizedDescription }
            reportError(error)
        }
        if case let .failure(error) = dated, !isCancellation(error) { reportError(error) }
        if case let .failure(error) = year, !isCancellation(error) { reportError(error) }
        hasLoaded = true
        if case .success = first { saveSnapshot() }
        await loadAlerts()
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore, let cursor else { return }
        isLoadingMore = true
        pageFailed = false
        let token = generation
        defer { isLoadingMore = false }
        do {
            let page = try await client.feed(cursor, Self.pageSize)
            guard token == generation else { return }
            let known = Set(events.map(\.id))
            events += page.items.filter { !known.contains($0.id) }
            self.cursor = page.endCursor
            hasMore = page.hasMore
        } catch {
            guard !isCancellation(error) else { return }
            pageFailed = true
            reportError(error)
        }
    }

    /// Reached a row near the end of what is loaded.
    func prefetchIfNeeded(for id: String) async {
        let ids = events.map(\.id)
        guard let index = ids.firstIndex(of: id), index >= ids.count - 8 else { return }
        await loadMore()
    }

    // MARK: - Actions

    func loadAlerts() async {
        alertsSilenced = await client.alertsSilenced()
    }

    /// Opening Amis puts its dot out; the rings keep what they showed until the
    /// next visit.
    private func markFriendsSeen(now: Date = .now) {
        ringsSeenAt = friendsSeenAt
        friendsSeenAt = now
        defaults?.set(now, forKey: Self.friendsSeenKey)
    }

    func take(_ event: FeedEvent, as format: BookFormat) async {
        do {
            try await client.takeFriendBook(event.friendId, event.bookId, format)
            taken.insert(event.bookId)
        } catch {
            guard !isCancellation(error) else { return }
            reportError(error)
        }
    }

    func add(_ news: NarratorNews) async {
        do {
            try await client.addRecording(news)
        } catch {
            guard !isCancellation(error) else { return }
            reportError(error)
        }
    }

    func invite() async {
        isInviting = true
        defer { isInviting = false }
        do {
            invitation = try await client.invite()
        } catch {
            guard !isCancellation(error) else { return }
            reportError(error)
        }
    }

    /// Written off the main actor, the feed's first page at most.
    private func saveSnapshot() {
        guard let cache else { return }
        let snapshot = Snapshot(
            events: Array(events.prefix(Self.pageSize)),
            releases: releases,
            yearReleases: yearReleases,
            narratorNews: narratorNews
        )
        Task.detached { cache.write(snapshot) }
    }

    private func capture<T: Sendable>(_ work: @Sendable () async throws -> T) async -> Result<T, Error> {
        do { return .success(try await work()) } catch { return .failure(error) }
    }
}
