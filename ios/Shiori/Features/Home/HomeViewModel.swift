import Foundation
import SwiftUI

@MainActor
@Observable
final class HomeViewModel {
    init() {
        dashboard = cache.read()
        releases = releasesCache.read() ?? []
        friendFavorites = favoritesCache.read() ?? []
    }

    private(set) var dashboard: Dashboard?
    /// What is new in the sagas followed, read or heard: the volumes just out,
    /// the newest first, then what is announced, the soonest first — the next
    /// volume of each saga, both formats together, and the recordings the
    /// reader awaits once they have a date.
    private(set) var releases: [HomeRelease] = []
    /// What the reader's friends hearted lately, the newest first.
    private(set) var friendFavorites: [FriendFavorite] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    /// Bringing last session's figures up to date failed: the ones on screen
    /// are from last time, and the leading row offers to try again.
    private(set) var refreshFailed = false
    /// The server has answered at least once, so what is on screen is no
    /// longer the snapshot.
    private var loaded = false

    /// The last dashboard on disk. Bump the version whenever `Dashboard`
    /// changes shape.
    private let cache = SnapshotCache<Dashboard>("dashboard", version: 4)
    private let releasesCache = SnapshotCache<[HomeRelease]>("dashboard-releases", version: 3)
    private let favoritesCache = SnapshotCache<[FriendFavorite]>("dashboard-friend-favorites", version: 1)

    /// How many releases the dashboard lines up; the rest are Découvrir's.
    private static let releasesShown = 10

    /// Says whether it failed. One skipped because another was already on its
    /// way, or one called off, did not: the figures are whatever that other
    /// one brings.
    @discardableResult
    func load() async -> Bool {
        guard !isLoading else { return false }
        isLoading = true
        errorMessage = nil
        // Side by side with the figures, and never in their way: a section
        // that could not be brought up to date keeps what it last showed.
        async let releases = Self.fetchReleases()
        async let favorites = try? FriendsAPI.recentFavorites()
        do {
            let fetched = try await HomeAPI.dashboard()
            // Over figures already on screen, the cards change in place rather
            // than the whole page redrawing at once.
            withAnimation(dashboard == nil ? nil : .smooth) { dashboard = fetched }
            loaded = true
            // Fresh figures: whatever an earlier refresh said is no longer true.
            refreshFailed = false
            let cache = cache
            Task.detached { cache.write(fetched) }
        } catch {
            keep(releases: await releases, favorites: await favorites)
            isLoading = false
            guard !isCancellation(error) else { return false }
            // The last dashboard stays on screen: blanking good figures because a
            // refresh failed reads as data loss.
            errorMessage = reportError(error)
            return true
        }
        keep(releases: await releases, favorites: await favorites)
        isLoading = false
        return false
    }

    /// A section that came back replaces the one on screen, and is kept for
    /// the next launch.
    private func keep(releases: [HomeRelease]?, favorites: [FriendFavorite]?) {
        if let releases {
            withAnimation(.smooth) { self.releases = releases }
            let cache = releasesCache
            Task.detached { cache.write(releases) }
        }
        if let favorites {
            withAnimation(.smooth) { friendFavorites = favorites }
            let cache = favoritesCache
            Task.detached { cache.write(favorites) }
        }
    }

    /// The releases alone, when an edition was awaited or given up: the
    /// figures around them have not moved.
    func reloadReleases() async {
        keep(releases: await Self.fetchReleases(), favorites: nil)
    }

    /// Découvrir's rows in both formats: the volumes just out, the newest
    /// first, then the volumes still to come, the soonest first, among which
    /// the recordings awaited that have a date. Nil when either format could
    /// not be read; the awaited recordings are left out when they could not.
    private static func fetchReleases() async -> [HomeRelease]? {
        async let books = try? DiscoverAPI.discovery(format: .book)
        async let audiobooks = try? DiscoverAPI.discovery(format: .audiobook)
        async let awaited = try? AwaitedAPI.awaited(format: .audiobook)
        guard let books = await books, let audiobooks = await audiobooks else { return nil }
        let rows = books.rows + audiobooks.rows
        let recent = rows
            .flatMap { saga in saga.recent.map { DiscoveryVolume(saga: saga, volume: $0) } }
            .sorted { ($0.volume.date ?? "", $0.volume.number) > ($1.volume.date ?? "", $1.volume.number) }
            .map(HomeRelease.volume)
        let nextVolumes = rows.compactMap { row -> HomeRelease? in
            guard let next = row.releases.next else { return nil }
            return .volume(DiscoveryVolume(saga: row, volume: next))
        }
        let awaitedRecordings = (await awaited ?? [])
            .filter { $0.state == .announced }
            .map(HomeRelease.awaited)
        let upcoming = (nextVolumes + awaitedRecordings)
            .compactMap { release -> (HomeRelease, String)? in
                guard let date = release.date, ReleaseDateText.isUpcoming(date) else { return nil }
                return (release, ReleaseDateText.lastDay(date))
            }
            .sorted { $0.1 != $1.1 ? $0.1 < $1.1 : $0.0.name.localizedStandardCompare($1.0.name) == .orderedAscending }
            .map(\.0)
        return Array((recent + upcoming).prefix(releasesShown))
    }

    /// The tab appeared: a dashboard still showing last session's snapshot
    /// refreshes it under the leading spinner, one never loaded loads. A
    /// dashboard the server already answered asks nothing: every write posts
    /// the change notice this tab listens to.
    func loadOnAppear() async {
        guard !loaded, !isLoading else { return }
        if dashboard != nil {
            await refresh()
        } else {
            await load()
        }
    }

    /// Bring the snapshot on screen up to date without taking it away — and
    /// the retry when that failed.
    func refresh() async {
        refreshFailed = false
        refreshFailed = await load()
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
