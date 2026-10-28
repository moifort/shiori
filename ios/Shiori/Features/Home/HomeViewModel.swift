import Foundation
import SwiftUI

@MainActor
@Observable
final class HomeViewModel {
    /// - Parameter caching: off in tests, which must neither read nor leave
    ///   a snapshot on disk.
    init(client: HomeClient, caching: Bool = true, seenStore: SeenReleases = SeenReleases()) {
        self.client = client
        self.seenStore = seenStore
        seenReleases = seenStore.all
        if caching {
            cache = SnapshotCache("dashboard", version: 5)
            releasesCache = SnapshotCache("dashboard-releases", version: 3)
            discoveriesCache = SnapshotCache("dashboard-discoveries", version: 3)
        } else {
            (cache, releasesCache, discoveriesCache) = (nil, nil, nil)
        }
        dashboard = cache?.read()
        releases = releasesCache?.read() ?? []
        discoveries = discoveriesCache?.read()
    }

    private let client: HomeClient
    private let seenStore: SeenReleases

    /// The releases the reader marked seen from the carousel, kept on the
    /// device.
    private var seenReleases: Set<HomeRelease.ID>
    /// The ones marked seen since the page opened: kept on screen, their eye
    /// filled, until the reader leaves the page.
    private var heldReleases: Set<HomeRelease.ID> = []

    /// What the carousel leaves out: the releases seen, but those just marked
    /// while the page is open.
    var hiddenReleases: Set<HomeRelease.ID> { seenReleases.subtracting(heldReleases) }

    private(set) var dashboard: Dashboard?
    /// What is new in the sagas followed, read or heard: the volumes just out,
    /// the newest first, then what is announced, the soonest first — the next
    /// volume of each saga, both formats together, and the recordings the
    /// reader awaits once they have a date.
    private(set) var releases: [HomeRelease] = []
    /// The month's discoveries, drawn as covers alone.
    private(set) var discoveries: MonthlyDiscoveries?
    /// The month's selection is being made at the home's request: the first
    /// look of a month waits for the model, about a minute.
    private(set) var isLookingUpDiscoveries = false

    /// Whether the month's selection is on its way, asked for here or
    /// elsewhere: the hero waits on it.
    var isSearchingDiscoveries: Bool {
        isLookingUpDiscoveries
            || (discoveries?.month == MonthlyDiscoveries.month(of: .now) && discoveries?.status == .searching)
    }

    /// How often a look that found the selection being made asks again, and
    /// for how long at most: a generation runs about a minute and a half.
    private static let searchPoll: Duration = .seconds(5)
    private static let searchPolls = 40
    /// The discoveries the reader just took from the carousel's "+": the
    /// server drops them from the month's line, but they stay on screen, their
    /// check showing, until the reader leaves the page.
    private var taken: [Suggestion] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    /// The server has answered at least once, so what is on screen is no
    /// longer the snapshot.
    private var loaded = false
    /// The server has told the month's discoveries at least once. Until then
    /// the selection is not known to be missing — a snapshot on disk may be
    /// last month's — so none is asked for: the dashboard often arrives
    /// before the discoveries are read.
    private var discoveriesRead = false

    /// The last dashboard on disk. Bump the version whenever `Dashboard`
    /// changes shape.
    private let cache: SnapshotCache<Dashboard>?
    private let releasesCache: SnapshotCache<[HomeRelease]>?
    private let discoveriesCache: SnapshotCache<MonthlyDiscoveries>?

    /// How many releases the dashboard lines up; the rest are Découvrir's.
    private static let releasesShown = 10

    /// The load on its way, which a second ask waits on.
    private var loading: Task<Void, Never>?
    /// Something asked for the page again while a load was on its way: a pull,
    /// or a write that load may have left before. It runs once more before
    /// anyone waiting is answered.
    private var reloadAsked = false

    /// Asked again while a load is on its way — back from the background,
    /// where a fresh token, a new connection and figures rebuilt after the
    /// nightly sync take a few seconds — a pull holds its spinner until the
    /// page is up to date, rather than returning at once over the figures
    /// still on screen.
    func load() async {
        if let loading {
            reloadAsked = true
            await loading.value
            return
        }
        isLoading = true
        let task = Task {
            repeat {
                reloadAsked = false
                await refresh()
            } while reloadAsked
        }
        loading = task
        await task.value
        loading = nil
        isLoading = false
    }

    private func refresh() async {
        errorMessage = nil
        // Apart from the rest: the first look of a month waits for the model,
        // and the figures must not wait with it.
        Task { await loadDiscoveries() }
        // Side by side with the figures, and never in their way: a section
        // that could not be brought up to date keeps what it last showed.
        let client = client
        async let releases = Self.fetchReleases(client)
        do {
            let fetched = try await client.dashboard()
            // Over figures already on screen, the cards change in place rather
            // than the whole page redrawing at once.
            withAnimation(dashboard == nil ? nil : .smooth) { dashboard = fetched }
            loaded = true
            if let cache { Task.detached { cache.write(fetched) } }
            // The shelf is known: a month without its selection gets one made.
            Task { await lookUpDiscoveriesIfDue() }
        } catch {
            keep(releases: await releases)
            guard !isCancellation(error) else { return }
            // The last dashboard stays on screen and says nothing: blanking good
            // figures because a refresh failed reads as data loss, and a pull
            // tries again.
            errorMessage = reportError(error)
            return
        }
        keep(releases: await releases)
    }

    /// The releases, when they came back, replace the ones on screen and are
    /// kept for the next launch.
    private func keep(releases: [HomeRelease]?) {
        guard let releases else { return }
        withAnimation(.smooth) { self.releases = releases }
        if let cache = releasesCache { Task.detached { cache.write(releases) } }
    }

    /// The discoveries alone: read in the printed format, as Découvrir draws
    /// its line by default. Kept as they were when they could not be read.
    /// A month found without its selection gets one made, once the shelf is
    /// known to hold books.
    func loadDiscoveries() async {
        guard let found = try? await client.discoveries() else { return }
        discoveriesRead = true
        show(found)
        await lookUpDiscoveriesIfDue()
    }

    /// Asks for the month's selection to be made, and again every few seconds
    /// while it is, when the shelf has books and the month has none: a reader
    /// who imported a library, or a month that just began. The server makes
    /// one selection a month per reader, never twice a day, whoever asks, so
    /// the home's look costs the model nothing Découvrir's would not have.
    func lookUpDiscoveriesIfDue() async {
        guard !isLookingUpDiscoveries, discoveriesRead, let dashboard, !dashboard.libraryIsEmpty,
            Self.selectionIsDue(discoveries)
        else { return }
        isLookingUpDiscoveries = true
        defer { isLookingUpDiscoveries = false }
        // A request given up on while the server still makes the selection
        // — a slow generation outlasting the app's wait — is asked again a
        // few times before it is left to the next look.
        var failures = 0
        for _ in 0..<Self.searchPolls {
            do {
                let found = try await client.lookUpDiscoveries()
                show(found)
                guard found.status == .searching else { return }
            } catch {
                guard !isCancellation(error) else { return }
                failures += 1
                guard failures < 3 else { return }
            }
            do { try await Task.sleep(for: Self.searchPoll) } catch { return }
        }
    }

    /// Whether the month's selection is still to be made or on its way: none
    /// for this month, or one being made elsewhere, which is waited on too.
    static func selectionIsDue(_ discoveries: MonthlyDiscoveries?, now: Date = .now) -> Bool {
        guard let discoveries, discoveries.month == MonthlyDiscoveries.month(of: now) else { return true }
        return discoveries.status != .ready
    }

    private func show(_ found: MonthlyDiscoveries) {
        withAnimation(.smooth) { discoveries = keepingTaken(found) }
        if let cache = discoveriesCache { Task.detached { cache.write(found) } }
    }

    /// A discovery taken from the carousel: kept where it stands through the
    /// reloads its own write sets off.
    func hold(_ suggestion: Suggestion) {
        guard !taken.contains(where: { $0.id == suggestion.id }) else { return }
        taken.append(suggestion)
    }

    /// The reader left the page: the discoveries they took and the releases
    /// they saw leave the line, out of sight, before they come back.
    func releaseTaken() async {
        heldReleases = []
        guard !taken.isEmpty else { return }
        taken = []
        await loadDiscoveries()
    }

    /// A release marked seen from the carousel's eye: kept on the device, and
    /// on screen until the reader leaves the page.
    func see(_ release: HomeRelease) {
        heldReleases.insert(release.id)
        seenReleases.insert(release.id)
        seenStore.see(release.id)
    }

    /// The eye pressed again: the release is put forward again.
    func unsee(_ release: HomeRelease) {
        seenReleases.remove(release.id)
        seenStore.unsee(release.id)
    }

    /// The line the server sent, with the discoveries taken since the page
    /// opened put back where they stood.
    private func keepingTaken(_ found: MonthlyDiscoveries) -> MonthlyDiscoveries {
        guard !taken.isEmpty, let shown = discoveries?.suggestions else { return found }
        var suggestions = found.suggestions
        for suggestion in taken where !suggestions.contains(where: { $0.id == suggestion.id }) {
            let index = shown.firstIndex { $0.id == suggestion.id } ?? suggestions.count
            suggestions.insert(suggestion, at: min(index, suggestions.count))
        }
        return MonthlyDiscoveries(month: found.month, status: found.status, suggestions: suggestions)
    }

    /// The releases alone, when an edition was awaited or given up: the
    /// figures around them have not moved.
    func reloadReleases() async {
        keep(releases: await Self.fetchReleases(client))
    }

    /// Découvrir's rows in both formats and the editions the reader awaits: the
    /// volumes and the editions awaited out in the last month, the newest
    /// first, then the volumes and the editions awaited still to come, the
    /// soonest first. An edition awaited moves from one to the other the day
    /// it comes out, rather than leaving the card. Nil when either format of
    /// the rows could not be read; the editions awaited are left out when they
    /// could not.
    private static func fetchReleases(_ client: HomeClient) async -> [HomeRelease]? {
        async let books = try? client.discovery(.book)
        async let audiobooks = try? client.discovery(.audiobook)
        async let awaitedRecordings = try? client.awaited(.audiobook)
        async let awaitedTranslations = try? client.awaited(.book)
        guard let books = await books, let audiobooks = await audiobooks else { return nil }
        let rows = books.rows + audiobooks.rows
        let awaited = (await awaitedRecordings ?? []) + (await awaitedTranslations ?? [])
        let recentVolumes = rows
            .flatMap { saga in saga.recent.map { DiscoveryVolume(saga: saga, volume: $0) } }
            .map(HomeRelease.volume)
        // Découvrir's window for a volume just out, applied to the editions
        // awaited: only a day known to the day says when it came out.
        let since = Date.now.addingTimeInterval(-Double(recentDays) * 86_400)
            .formatted(.iso8601.year().month().day())
        let recentAwaited = awaited
            .filter { edition in
                guard edition.state == .available, let date = edition.date, date.count == 10 else { return false }
                return date >= since
            }
            .map(HomeRelease.awaited)
        let recent = (recentVolumes + recentAwaited)
            .sorted { ($0.date ?? "", $1.name) > ($1.date ?? "", $0.name) }
        let nextVolumes = rows.compactMap { row -> HomeRelease? in
            guard let next = row.releases.next else { return nil }
            return .volume(DiscoveryVolume(saga: row, volume: next))
        }
        let awaitedComing = awaited
            .filter { $0.state == .announced }
            .map(HomeRelease.awaited)
        let upcoming = (nextVolumes + awaitedComing)
            .compactMap { release -> (HomeRelease, String)? in
                guard let date = release.date, ReleaseDateText.isUpcoming(date) else { return nil }
                return (release, ReleaseDateText.lastDay(date))
            }
            .sorted { $0.1 != $1.1 ? $0.1 < $1.1 : $0.0.name.localizedStandardCompare($1.0.name) == .orderedAscending }
            .map(\.0)
        return Array((recent + upcoming).prefix(releasesShown))
    }

    /// How long a volume or an edition awaited counts as just out, in days:
    /// Découvrir's own window for its "Nouvelles parutions".
    private static let recentDays = 30

    /// The tab appeared: a dashboard still showing last session's snapshot
    /// is brought up to date silently, one never loaded loads. A dashboard the
    /// server already answered asks nothing: every write posts the change
    /// notice this tab listens to.
    func loadOnAppear() async {
        guard !loaded, !isLoading else { return }
        await load()
    }

    /// A discovery turned down from its page: off the strip, and the next
    /// one comes in.
    func dismiss(_ suggestion: Suggestion, reason: DismissalReason) async {
        do { try await client.dismissSuggestion(suggestion.id, reason) } catch { _ = reportError(error) }
        await loadDiscoveries()
    }

    /// The carousel's thumb, pressed and pressed again: each write waits on
    /// the one before for the same discovery, so a dismissal taken back at
    /// once never reaches the server before the dismissal itself.
    private var thumbWrites: [Suggestion.ID: Task<Void, Never>] = [:]

    /// "Pas intéressé" from the carousel: held on screen, its thumb red,
    /// until the reader leaves the page.
    func turnDown(_ suggestion: Suggestion) {
        hold(suggestion)
        queueThumbWrite(for: suggestion) { [client] in
            try await client.dismissSuggestion(suggestion.id, .notInterested)
        }
    }

    /// The red thumb pressed again: the dismissal is taken back, and the
    /// discovery stays in the line.
    func takeBack(_ suggestion: Suggestion) {
        queueThumbWrite(for: suggestion) { [client] in
            try await client.reconsiderSuggestion(suggestion.id)
        }
    }

    private func queueThumbWrite(for suggestion: Suggestion, _ write: @escaping @Sendable () async throws -> Void) {
        let previous = thumbWrites[suggestion.id]
        thumbWrites[suggestion.id] = Task {
            await previous?.value
            do { try await write() } catch { _ = reportError(error) }
            await loadDiscoveries()
        }
    }

    func stopAwaiting(_ edition: AwaitedEdition) async {
        do { try await client.stopAwaiting(edition.id) } catch { _ = reportError(error) }
    }

    /// The reading card's buttons. The figures follow through the change
    /// notice every write posts; a failure is said in an alert, the page kept.
    func finish(_ book: Book) async {
        do { try await client.finish(book.id) } catch { actionError = reportError(error) }
    }

    /// Why the page sheet could not save, said in it; nil once saved.
    func recordPage(_ book: Book, page: Int?, then status: ReadingStatus?) async -> String? {
        do {
            try await client.recordPage(book.id, page, status)
            return nil
        } catch {
            return reportError(error)
        }
    }

    func rate(_ book: Book, stars: Double) async {
        do { try await client.rate(book.id, stars) } catch { actionError = reportError(error) }
    }

    /// What a button of the page could not do.
    var actionError: String?

    func genreInsights() async throws -> GenreInsights {
        try await client.genreInsights()
    }
}

/// One tile of the dashboard's news: a volume of a saga followed, or a
/// recording the reader awaits.
enum HomeRelease: Identifiable, Codable, Sendable {
    case volume(DiscoveryVolume)
    case awaited(AwaitedEdition)

    var id: String {
        switch self {
        case let .volume(release): release.id
        case let .awaited(edition): "awaited-\(edition.id)"
        }
    }

    /// `YYYY`, `YYYY-MM` or `YYYY-MM-DD`; nil for what is announced undated.
    var date: String? {
        switch self {
        case let .volume(release): release.volume.date
        case let .awaited(edition): edition.date
        }
    }

    /// What orders two releases out the same day: the saga, or the title.
    var name: String {
        switch self {
        case let .volume(release): release.saga.series.name
        case let .awaited(edition): edition.title
        }
    }
}
