import Foundation
import SwiftUI

@MainActor
@Observable
final class HomeViewModel {
    /// - Parameter caching: off in tests, which must neither read nor leave
    ///   a snapshot on disk.
    init(client: HomeClient, caching: Bool = true) {
        self.client = client
        if caching {
            cache = SnapshotCache("dashboard", version: 4)
            releasesCache = SnapshotCache("dashboard-releases", version: 3)
            favoritesCache = SnapshotCache("dashboard-friend-favorites", version: 1)
            discoveriesCache = SnapshotCache("dashboard-discoveries", version: 2)
        } else {
            (cache, releasesCache, favoritesCache, discoveriesCache) = (nil, nil, nil, nil)
        }
        dashboard = cache?.read()
        releases = releasesCache?.read() ?? []
        friendFavorites = favoritesCache?.read() ?? []
        discoveries = discoveriesCache?.read()
    }

    private let client: HomeClient

    private(set) var dashboard: Dashboard?
    /// What is new in the sagas followed, read or heard: the volumes just out,
    /// the newest first, then what is announced, the soonest first — the next
    /// volume of each saga, both formats together, and the recordings the
    /// reader awaits once they have a date.
    private(set) var releases: [HomeRelease] = []
    /// What the reader's friends hearted lately, the newest first.
    private(set) var friendFavorites: [FriendFavorite] = []
    /// The month's discoveries, drawn as covers alone.
    private(set) var discoveries: MonthlyDiscoveries?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    /// The server has answered at least once, so what is on screen is no
    /// longer the snapshot.
    private var loaded = false

    /// The last dashboard on disk. Bump the version whenever `Dashboard`
    /// changes shape.
    private let cache: SnapshotCache<Dashboard>?
    private let releasesCache: SnapshotCache<[HomeRelease]>?
    private let favoritesCache: SnapshotCache<[FriendFavorite]>?
    private let discoveriesCache: SnapshotCache<MonthlyDiscoveries>?

    /// How many releases the dashboard lines up; the rest are Découvrir's.
    private static let releasesShown = 10

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        // Apart from the rest: the first look of a month waits for the model,
        // and the figures must not wait with it.
        Task { await loadDiscoveries() }
        // Side by side with the figures, and never in their way: a section
        // that could not be brought up to date keeps what it last showed.
        let client = client
        async let releases = Self.fetchReleases(client)
        async let favorites = try? client.recentFavorites()
        do {
            let fetched = try await client.dashboard()
            // Over figures already on screen, the cards change in place rather
            // than the whole page redrawing at once.
            withAnimation(dashboard == nil ? nil : .smooth) { dashboard = fetched }
            loaded = true
            if let cache { Task.detached { cache.write(fetched) } }
        } catch {
            keep(releases: await releases, favorites: await favorites)
            isLoading = false
            guard !isCancellation(error) else { return }
            // The last dashboard stays on screen and says nothing: blanking good
            // figures because a refresh failed reads as data loss, and a pull
            // tries again.
            errorMessage = reportError(error)
            return
        }
        keep(releases: await releases, favorites: await favorites)
        isLoading = false
    }

    /// A section that came back replaces the one on screen, and is kept for
    /// the next launch.
    private func keep(releases: [HomeRelease]?, favorites: [FriendFavorite]?) {
        if let releases {
            withAnimation(.smooth) { self.releases = releases }
            if let cache = releasesCache { Task.detached { cache.write(releases) } }
        }
        if let favorites {
            withAnimation(.smooth) { friendFavorites = favorites }
            if let cache = favoritesCache { Task.detached { cache.write(favorites) } }
        }
    }

    /// The discoveries alone: read in the printed format, as Découvrir draws
    /// its line by default, never made here — only Découvrir asks for a month's
    /// selection. Kept as they were when they could not be read.
    func loadDiscoveries() async {
        guard let found = try? await client.discoveries() else { return }
        withAnimation(.smooth) { discoveries = found }
        if let cache = discoveriesCache { Task.detached { cache.write(found) } }
    }

    /// The releases alone, when an edition was awaited or given up: the
    /// figures around them have not moved.
    func reloadReleases() async {
        keep(releases: await Self.fetchReleases(client), favorites: nil)
    }

    /// Découvrir's rows in both formats and the editions the reader awaits: the
    /// volumes and the editions awaited out in the last two weeks, the newest
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
    private static let recentDays = 14

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

    func stopAwaiting(_ edition: AwaitedEdition) async {
        do { try await client.stopAwaiting(edition.id) } catch { _ = reportError(error) }
    }

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
