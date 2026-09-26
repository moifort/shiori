import Foundation
import SwiftUI

/// Owns the Découvrir tab's rows, one list per format, and the one in-flight
/// load. The tab opens on the rows it last showed: a `SnapshotCache` hands them
/// back from disk before a byte is asked of the network, and the fetch brings
/// them up to date silently underneath.
@MainActor
@Observable
final class DiscoverViewModel {
    init() {
        feed = cache.read() ?? DiscoveryFeed()
    }

    private(set) var feed: DiscoveryFeed
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    /// The sagas never looked up are being looked up on the web, behind a
    /// loader when the tab has nothing to show yet, a row above the others
    /// otherwise.
    private(set) var isLookingUp = false

    /// Bringing last session's rows up to date failed: the rows are the ones
    /// from last time, and the leading row offers to try again.
    private(set) var refreshFailed = false
    /// The formats the server has answered for since launch, so their rows are
    /// no longer the snapshot.
    private var loaded: Set<ReleaseFormat> = []
    /// The formats already looked up this session: a lookup that left sagas
    /// behind — out of budget, or failed — is not started again on every
    /// look, and the hourly pass takes the rest.
    private var lookedUp: Set<ReleaseFormat> = []

    /// Bump the version whenever `DiscoveryFeed` changes shape.
    private let cache = SnapshotCache<DiscoveryFeed>("discovery", version: 2)

    /// The rows of a format, nil until they were ever loaded.
    func rows(_ format: ReleaseFormat) -> [SagaDiscovery]? { feed.rows[format] }

    /// Says whether it failed. One skipped because another was already on its
    /// way, or one called off, did not.
    @discardableResult
    func load(_ format: ReleaseFormat) async -> Bool {
        guard !isLoading else { return false }
        isLoading = true
        errorMessage = nil
        let page: DiscoveryPage
        do {
            page = try await DiscoverAPI.discovery(format: format)
            show(page.rows, in: format)
            loaded.insert(format)
            refreshFailed = false
        } catch {
            isLoading = false
            guard !isCancellation(error) else { return false }
            // The last rows stay on screen: blanking good rows because a
            // refresh failed reads as data loss.
            errorMessage = reportError(error)
            return true
        }
        isLoading = false
        // Sagas nobody ever looked up are looked up now, rather than leaving
        // the tab empty until the hourly pass.
        if page.unwatched > 0, !lookedUp.contains(format) {
            await lookUp(format)
        }
        await askForAlertsIfWorthIt(format)
        return false
    }

    /// Look up on the web the sagas of that format never looked up.
    private func lookUp(_ format: ReleaseFormat) async {
        lookedUp.insert(format)
        isLookingUp = true
        defer { isLookingUp = false }
        do {
            show(try await DiscoverAPI.lookUp(format: format).rows, in: format)
        } catch {
            guard !isCancellation(error) else { return }
            errorMessage = reportError(error)
        }
    }

    /// The tab appeared, or its format changed: rows still showing last
    /// session's snapshot are brought up to date, rows never loaded load.
    /// Rows the server already answered ask nothing: every write posts the
    /// change notice this tab listens to.
    func loadOnAppear(_ format: ReleaseFormat) async {
        guard !loaded.contains(format) else { return }
        await refresh(format)
    }

    /// Bring the rows on screen up to date without taking them away — and the
    /// retry when that failed.
    func refresh(_ format: ReleaseFormat) async {
        refreshFailed = false
        refreshFailed = await load(format)
    }

    /// The library changed: the formats already loaded are asked again.
    func reload() async {
        for format in loaded { await load(format) }
    }

    /// Over rows already on screen, the new ones slide into place and push the
    /// others aside rather than the whole list redrawing at once.
    private func show(_ fetched: [SagaDiscovery], in format: ReleaseFormat) {
        withAnimation(feed.rows[format] == nil ? nil : .smooth) { feed.rows[format] = fetched }
        let snapshot = feed
        let cache = cache
        Task.detached { cache.write(snapshot) }
    }

    /// The alert is on by default, but the system asks once: the first time
    /// the tab has a volume to announce, which is when saying yes means
    /// something. Asked once, the system never shows it again.
    private func askForAlertsIfWorthIt(_ format: ReleaseFormat) async {
        guard feed.rows[format]?.contains(where: { $0.releases.next != nil }) == true else { return }
        _ = await PushRegistrar.shared.requestPermission()
    }
}
