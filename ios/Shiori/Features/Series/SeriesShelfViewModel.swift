import Foundation
import SwiftUI

/// Owns the series screen of the Library tab: every saga the reader follows,
/// loaded at once — a few dozen rows — and read three ways: the next volume
/// of each saga in progress, the volumes announced, and every saga under its
/// filter. The sagas set aside have a page of their own.
@MainActor
@Observable
final class SeriesShelfViewModel {
    init(client: SeriesClient, filter: SeriesShelfFilter = .all, caching: Bool = true) {
        self.client = client
        self.filter = filter
        cache = caching ? SnapshotCache("series-shelf", version: 1) : nil
        series = cache?.read() ?? []
    }

    private let client: SeriesClient
    private let cache: SnapshotCache<[FollowedSeries]>?

    private(set) var series: [FollowedSeries]
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var filter: SeriesShelfFilter

    private var loaded = false
    /// The most sagas asked for: a page of the server's cap, then the next.
    private static let pageSize = 200
    private static let maxPages = 5

    /// The sagas being read, the next volume of each: what to pick up next.
    var upNext: [(series: FollowedSeries, volume: FollowedSeries.NextVolume)] {
        followed
            .filter { $0.state == .inProgress }
            .compactMap { saga in saga.nextVolume.map { (saga, $0) } }
    }

    /// The volumes announced, as the saga screen announces each, the nearest
    /// first; one announced for a date nobody found comes last.
    var releases: [(series: FollowedSeries, volume: DiscoveredVolume)] {
        followed
            .compactMap { saga in saga.announced.map { (saga, $0) } }
            .filter { $0.volume.date.map { ReleaseDateText.isUpcoming($0) } ?? true }
            .sorted { lastDay(of: $0.volume) < lastDay(of: $1.volume) }
    }

    private func lastDay(of volume: DiscoveredVolume) -> String {
        volume.date.map(ReleaseDateText.lastDay) ?? "\u{FFFF}"
    }

    var filters: [SeriesShelfFilter] { SeriesShelfFilter.offered(for: series) }

    var filtered: [FollowedSeries] { series.filter(filter.keeps) }

    var setAside: [FollowedSeries] { series.filter(\.isSetAside) }

    private var followed: [FollowedSeries] { series.filter { !$0.isSetAside } }

    func loadOnAppear() async {
        guard !loaded, !isLoading else { return }
        await load()
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            var fetched: [FollowedSeries] = []
            var cursor: String?
            for _ in 0..<Self.maxPages {
                let page = try await client.page(Self.pageSize, cursor)
                fetched += page.items
                cursor = page.endCursor
                guard page.hasMore, cursor != nil else { break }
            }
            withAnimation(series.isEmpty ? nil : .smooth) { series = fetched }
            loaded = true
            if !filters.contains(filter) { filter = .all }
            if let cache { Task.detached { cache.write(fetched) } }
        } catch {
            isLoading = false
            guard !isCancellation(error) else { return }
            errorMessage = reportError(error)
            return
        }
        isLoading = false
    }

    /// Follows a saga set aside again: it goes back to "À suivre" and the
    /// releases.
    func follow(_ saga: FollowedSeries) async {
        do {
            _ = try await client.setFollowed(saga.seriesId, true)
            await load()
        } catch {
            guard !isCancellation(error) else { return }
            errorMessage = reportError(error)
        }
    }
}
