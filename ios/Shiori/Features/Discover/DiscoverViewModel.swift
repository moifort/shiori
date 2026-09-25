import Foundation
import SwiftUI

/// Owns the Découvrir tab's feed, the search the reader may start again, and
/// the one in-flight load. The tab opens on the feed it last showed: a
/// `SnapshotCache` hands it back from disk before a byte is asked of the
/// network, and the fetch brings it up to date silently underneath.
@MainActor
@Observable
final class DiscoverViewModel {
    init() {
        feed = cache.read()
    }

    private(set) var feed: DiscoverFeed?
    private(set) var isLoading = false
    /// The web is being searched again, behind the loader on a first opening
    /// or the toolbar's spinner after that.
    private(set) var isPreparing = false
    private(set) var errorMessage: String?

    /// Bringing last session's feed up to date failed: the rows are the ones
    /// from last time, and the leading row offers to try again.
    private(set) var refreshFailed = false
    /// The server has answered at least once, so the feed is no longer the
    /// snapshot.
    private var loaded = false

    /// The last feed on disk, every format together: the format is only a
    /// filter the screen reads it through. Bump the version whenever
    /// `DiscoverFeed` changes shape.
    private let cache = SnapshotCache<DiscoverFeed>("discover", version: 1)

    /// Says whether it failed. One skipped because another was already on its
    /// way, or one called off, did not: the feed is whatever that other one
    /// brings.
    @discardableResult
    func load() async -> Bool {
        guard !isLoading else { return false }
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await DiscoverAPI.feed()
            show(fetched)
            loaded = true
            // Fresh rows: whatever an earlier refresh said is no longer true.
            refreshFailed = false
        } catch {
            isLoading = false
            guard !isCancellation(error) else { return false }
            // The last feed stays on screen: blanking good rows because a
            // refresh failed reads as data loss.
            errorMessage = reportError(error)
            return true
        }
        isLoading = false
        // The first opening searches at once: a reader who came to see what is
        // coming should not have to ask for it.
        if let feed, feed.preparedAt == nil, !isPreparing {
            await prepare()
            return false
        }
        await askForAlertsIfWorthIt()
        return false
    }

    /// Search the web again for what is new.
    func prepare() async {
        isPreparing = true
        errorMessage = nil
        defer { isPreparing = false }
        do {
            show(try await DiscoverAPI.refresh())
        } catch {
            guard !isCancellation(error) else { return }
            errorMessage = reportError(error)
        }
        await askForAlertsIfWorthIt()
    }

    /// The tab appeared: a feed still showing last session's snapshot refreshes
    /// it, one never loaded loads. A feed the server already answered asks
    /// nothing: every write posts the change notice this tab listens to.
    func loadOnAppear() async {
        guard !loaded, !isLoading else { return }
        if feed != nil {
            await refresh()
        } else {
            await load()
        }
    }

    /// Bring the feed on screen up to date without taking it away — and the
    /// retry when that failed.
    func refresh() async {
        refreshFailed = false
        refreshFailed = await load()
    }

    /// Set a release aside for good: gone from the screen at once, and from the
    /// snapshot, so a relaunch does not draw it back for a moment.
    func dismiss(_ release: Release) async {
        withAnimation { feed?.remove(key: release.key) }
        do {
            try await DiscoverAPI.dismiss(key: release.key)
            if let feed { write(feed) }
        } catch {
            errorMessage = reportError(error)
            await load()
        }
    }

    /// Over rows already on screen, the new ones slide into place and push the
    /// others aside rather than the whole list redrawing at once.
    private func show(_ fetched: DiscoverFeed) {
        withAnimation(feed == nil ? nil : .smooth) { feed = fetched }
        write(fetched)
    }

    /// Only a feed the web was searched for is worth opening on: one never
    /// searched is the loader the search starts behind anyway.
    private func write(_ feed: DiscoverFeed) {
        guard feed.preparedAt != nil else { return }
        let cache = cache
        Task.detached { cache.write(feed) }
    }

    /// The alert is on by default, but the system asks once: the first time
    /// the tab has a release to announce, which is when saying yes means
    /// something. Asked once, the system never shows it again.
    private func askForAlertsIfWorthIt() async {
        guard let feed, !feed.upcoming.isEmpty else { return }
        _ = await PushRegistrar.shared.requestPermission()
    }
}
