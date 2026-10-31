import Foundation
import Observation

/// The Actualités tab's state: the friends' feed page by page, the releases
/// the calendar is laid from, the award card, and the pills that narrow them.
@MainActor @Observable
final class NewsViewModel {
    /// The page size of the feed: a few screens of rows.
    static let pageSize = 20

    private let client: NewsClient
    private var generation = 0

    private(set) var events: [FeedEvent] = []
    private(set) var hasMore = false
    private var cursor: String?
    private(set) var releases: [UpcomingRelease] = []
    private(set) var winner: AwardWinner?
    private(set) var narratorNews: [NarratorNews] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?
    private(set) var pageFailed = false
    /// Books the reader just took, greyed out at once.
    private(set) var taken: Set<String> = []
    private(set) var alertsSilenced = false
    private var winnerDismissed = false

    /// The pill chosen; nil is "Tout".
    var format: BookFormat?
    var horizon: ReleaseHorizon = .month
    var selectedDay: Int?

    init(client: NewsClient) {
        self.client = client
    }

    // MARK: - Reading

    var shownEvents: [FeedEvent] {
        events.filter { format == nil || $0.format == format }
            .map { event in
                var shown = event
                if taken.contains(event.bookId) { shown.inLibrary = true }
                return shown
            }
    }

    var shownReleases: [UpcomingRelease] {
        releases.filter { format == nil || $0.format == format }
    }

    /// The favourite author's soonest announcement, which opens the feed's
    /// second card.
    var spotlight: UpcomingRelease? {
        shownReleases.first { $0.author?.favorite == true && $0.date != nil }
    }

    /// The narrators' news the pills keep: recordings, so the audiobook pill
    /// and "Tout".
    var shownNarratorNews: [NarratorNews] {
        format == nil || format == .audiobook ? narratorNews : []
    }

    var shownWinner: AwardWinner? {
        guard let winner, !winnerDismissed else { return nil }
        guard let format else { return winner }
        return winner.cover.format == format ? winner : nil
    }

    func calendar(now: Date = .now) -> ReleaseCalendar {
        ReleaseCalendar(releases: shownReleases, now: now)
    }

    // MARK: - Loading

    func loadOnAppear() async {
        guard !hasLoaded else { return }
        await load()
    }

    /// The first page, the releases and the award, asked together. Over rows
    /// already on screen a failure says nothing.
    func load() async {
        generation += 1
        let token = generation
        isLoading = !hasLoaded
        defer { if token == generation { isLoading = false } }
        async let page = capture { try await client.feed(nil, Self.pageSize) }
        async let upcoming = capture { try await client.upcoming() }
        async let latest = capture { try await client.latestWinner() }
        async let narrated = capture { try await client.narratorNews() }
        let (first, dated, award, voices) = await (page, upcoming, latest, narrated)
        guard token == generation else { return }
        if case let .success(first) = first {
            events = first.items
            cursor = first.endCursor
            hasMore = first.hasMore
            errorMessage = nil
        } else if case let .failure(error) = first, !isCancellation(error) {
            if events.isEmpty { errorMessage = error.localizedDescription }
            reportError(error)
        }
        if case let .success(dated) = dated { releases = dated }
        if case let .success(award) = award { winner = award }
        if case let .success(voices) = voices { narratorNews = voices }
        if case let .failure(error) = dated, !isCancellation(error) { reportError(error) }
        hasLoaded = true
        selectedDay = nil
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

    /// Reached the row `prefetchThreshold` from the end.
    func prefetchIfNeeded(for id: String) async {
        let ids = shownEvents.map(\.id)
        guard let index = ids.firstIndex(of: id), index >= ids.count - 8 else { return }
        await loadMore()
    }

    // MARK: - Actions

    func loadAlerts() async {
        alertsSilenced = await client.alertsSilenced()
    }

    /// "Pas intéressé": the card leaves the feed for this session.
    func dismissWinner() {
        winnerDismissed = true
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

    func add(_ winner: AwardWinner) async {
        do {
            try await client.addWinner(winner)
        } catch {
            guard !isCancellation(error) else { return }
            reportError(error)
        }
    }

    private func capture<T: Sendable>(_ work: @Sendable () async throws -> T) async -> Result<T, Error> {
        do { return .success(try await work()) } catch { return .failure(error) }
    }
}
