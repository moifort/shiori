import Foundation
import SwiftUI

/// Owns the Découvrir tab's rows, one list per format drawn mixed, and the
/// one in-flight load. The tab opens on everything it last showed — the rows, the friends'
/// picks and the editions awaited: a `SnapshotCache` hands them back from disk
/// before a byte is asked of the network, and the fetches bring them up to
/// date silently underneath, the new rows sliding into place.
@MainActor
@Observable
final class DiscoverViewModel {
    init() {
        feed = cache.read() ?? DiscoveryFeed()
    }

    private(set) var feed: DiscoveryFeed
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    /// The first look at a format: everything the reader follows in it is
    /// being looked up on the web, and the tab has nothing to show until it is.
    private(set) var isLookingUp = false

    /// The formats the server has answered for since launch, so their rows are
    /// no longer the snapshot.
    private var loaded: Set<ReleaseFormat> = []
    /// The formats already looked up this session: a lookup that left sagas
    /// behind — out of budget, or failed — is not started again on every
    /// look, and the hourly pass takes the rest.
    private var lookedUp: Set<ReleaseFormat> = []

    /// Bump the version whenever `DiscoveryFeed` changes shape.
    private let cache = SnapshotCache<DiscoveryFeed>("discovery", version: 8)

    /// The rows of a format, nil until they were ever loaded.
    func rows(_ format: ReleaseFormat) -> [SagaDiscovery]? { feed.rows[format] }

    /// The sagas of both formats, read and heard side by side: the tab draws
    /// them mixed, the headphones on a recording's cover telling them apart.
    /// Nil until neither format was ever loaded.
    var rows: [SagaDiscovery]? {
        guard !feed.rows.isEmpty else { return nil }
        return ReleaseFormat.allCases.flatMap { feed.rows[$0] ?? [] }
    }

    /// The sagas with a volume announced, for the Books shelf: the soonest out
    /// first, a year alone read as its last day so "2027" comes after
    /// "2027-02-19", and the volumes nobody found a date for last.
    var upcoming: [SagaDiscovery] {
        (rows ?? [])
            .filter { $0.releases.next != nil }
            .sorted { lhs, rhs in
                let left = lhs.releases.next?.date.map(ReleaseDateText.lastDay)
                let right = rhs.releases.next?.date.map(ReleaseDateText.lastDay)
                guard left != right else {
                    return lhs.series.name.localizedStandardCompare(rhs.series.name) == .orderedAscending
                }
                guard let left else { return false }
                guard let right else { return true }
                return left < right
            }
    }

    /// Every volume just out of the sagas, for the Books shelf, each with its
    /// saga: the newest first.
    var recentVolumes: [DiscoveryVolume] {
        (rows ?? [])
            .flatMap { saga in saga.recent.map { DiscoveryVolume(saga: saga, volume: $0) } }
            .sorted { ($0.volume.date ?? "", $0.volume.number) > ($1.volume.date ?? "", $1.volume.number) }
    }

    /// The sagas with a volume just out, for the Series shelf: the newest out
    /// first.
    var recentSagas: [SagaDiscovery] {
        (rows ?? [])
            .filter { !$0.recent.isEmpty }
            .sorted { ($0.recent.first?.date ?? "") > ($1.recent.first?.date ?? "") }
    }

    /// The authors of both formats, one row per author: a writer read and
    /// heard is one face on the shelf, their news in both formats under it.
    private var authors: [AuthorNews] {
        var order: [String] = []
        var parts: [String: [AuthorNews.Part]] = [:]
        for format in ReleaseFormat.allCases {
            for row in feed.authors[format] ?? [] {
                if parts[row.author.id] == nil { order.append(row.author.id) }
                parts[row.author.id, default: []].append(AuthorNews.Part(format: format, row: row))
            }
        }
        return order.compactMap { id in parts[id].map(AuthorNews.init) }
    }

    /// The authors with a work announced, an edition awaited announced or a
    /// saga's volume announced, for the Authors shelf: the soonest out first,
    /// as the Books shelf orders its volumes.
    var upcomingAuthors: [AuthorNews] {
        authors
            .filter(\.hasComing)
            .sorted { lhs, rhs in
                let left = lhs.soonestComing
                let right = rhs.soonestComing
                guard left != right else {
                    return lhs.author.name.localizedStandardCompare(rhs.author.name) == .orderedAscending
                }
                guard let left else { return false }
                guard let right else { return true }
                return left < right
            }
    }

    /// The authors with a work just out, an edition awaited out or a saga's
    /// volume just out, for the Authors shelf: the newest out first.
    var recentAuthors: [AuthorNews] {
        authors
            .filter(\.hasOut)
            .sorted { ($0.newestOut ?? "") > ($1.newestOut ?? "") }
    }

    /// "Coups de cœur de vos amis", whatever the format: last session's until
    /// loaded, and last load's when a later one fails — the section is a
    /// suggestion, not worth an error of its own.
    var picks: FriendPicks { feed.picks }

    func loadPicks() async {
        do {
            let found = try await FriendsAPI.picks()
            withAnimation(.smooth) { feed.picks = found }
            saveSnapshot()
        } catch {
            _ = reportError(error)
        }
    }

    /// The editions awaited in a format, the ones out first: last session's
    /// until loaded, and last load's when a later one fails, as the friends'
    /// picks.
    func awaited(_ format: ReleaseFormat) -> [AwaitedEdition] { feed.awaited[format] ?? [] }

    /// "Bientôt disponible": the editions awaited in both formats, translated
    /// and recorded together, in `soonOrder`.
    var awaitedSoon: [AwaitedEdition] {
        Self.soonOrder(ReleaseFormat.allCases.flatMap(awaited))
    }

    /// The editions awaited still to come first, the soonest first and the
    /// undated last; then the ones out, the newest first; then the ones not
    /// announced yet, the latest awaited first.
    static func soonOrder(_ editions: [AwaitedEdition]) -> [AwaitedEdition] {
        func rank(_ edition: AwaitedEdition) -> Int {
            switch edition.state {
            case .announced: 0
            case .available: 1
            default: 2
            }
        }
        func day(_ edition: AwaitedEdition) -> String? { edition.date.map(ReleaseDateText.lastDay) }
        return editions.sorted { lhs, rhs in
            let (left, right) = (rank(lhs), rank(rhs))
            guard left == right else { return left < right }
            switch left {
            case 0:
                if day(lhs) != day(rhs) {
                    guard let leftDay = day(lhs) else { return false }
                    guard let rightDay = day(rhs) else { return true }
                    return leftDay < rightDay
                }
            case 1:
                if day(lhs) != day(rhs) {
                    guard let leftDay = day(lhs) else { return false }
                    guard let rightDay = day(rhs) else { return true }
                    return leftDay > rightDay
                }
            default:
                let (leftAt, rightAt) = (lhs.awaitedAt ?? .distantPast, rhs.awaitedAt ?? .distantPast)
                if leftAt != rightAt { return leftAt > rightAt }
            }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    func loadAwaited(_ format: ReleaseFormat) async {
        do {
            let found = try await AwaitedAPI.awaited(format: format)
            withAnimation(.smooth) { feed.awaited[format] = found }
            saveSnapshot()
        } catch {
            guard !isCancellation(error) else { return }
            _ = reportError(error)
        }
    }

    /// The award winners of the reader's genre in each format: nil until
    /// loaded, and when the reader reads no genre with awards enough. Not kept
    /// in the snapshot: a suggestion, asked anew on each visit.
    private(set) var awards: [ReleaseFormat: AwardShelf] = [:]

    /// The format the award winners are shown in: the book's, unless the
    /// reader follows and awaits nothing read — a reader of recordings alone
    /// wants to know which winners they can hear.
    var awardsFormat: ReleaseFormat {
        holdsNothing(in: .book) && !holdsNothing(in: .audiobook) ? .audiobook : .book
    }

    func loadAwards(_ format: ReleaseFormat) async {
        do {
            let found = try await AwardsAPI.shelf(format: format, genre: nil)
            withAnimation(.smooth) { awards[format] = found }
        } catch {
            guard !isCancellation(error) else { return }
            _ = reportError(error)
        }
    }

    /// Every format already shown is asked again.
    func reloadAwaited() async {
        for format in feed.awaited.keys { await loadAwaited(format) }
    }

    /// Gives the wait up, taking the edition off at once and putting it back
    /// if the server refused.
    func stopAwaiting(_ edition: AwaitedEdition) async {
        let before = feed.awaited[edition.format]
        let authorsBefore = feed.authors[edition.format]
        withAnimation(.smooth) {
            feed.awaited[edition.format]?.removeAll { $0.id == edition.id }
            feed.authors[edition.format] = authorsBefore?.compactMap { row in
                var row = row
                row.awaited.removeAll { $0.id == edition.id }
                return row.isEmpty ? nil : row
            }
        }
        do {
            try await AwaitedAPI.stop(id: edition.id)
            saveSnapshot()
        } catch {
            withAnimation(.smooth) {
                feed.awaited[edition.format] = before
                feed.authors[edition.format] = authorsBefore
            }
            errorMessage = reportError(error)
        }
    }

    /// How many sagas and authors the reader follows in a format, nil until it
    /// was loaded.
    func followed(_ format: ReleaseFormat) -> Int? { feed.followed[format] }

    /// Whether the reader follows and awaits nothing in a format, as last
    /// session's snapshot or the server says.
    func holdsNothing(in format: ReleaseFormat) -> Bool {
        followed(format) == 0 && awaited(format).isEmpty
    }

    func load(_ format: ReleaseFormat) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        let page: DiscoveryPage
        do {
            page = try await DiscoverAPI.discovery(format: format)
            feed.followed[format] = page.followed
            show(page, in: format)
            loaded.insert(format)
        } catch {
            isLoading = false
            guard !isCancellation(error) else { return }
            // The last rows stay on screen and say nothing: blanking good rows
            // because a refresh failed reads as data loss, and a pull tries again.
            errorMessage = reportError(error)
            return
        }
        isLoading = false
        // The very first look, when nothing the reader follows in this format
        // was ever looked up, is looked up now rather than leaving the tab
        // empty until the hourly pass. A saga or an author followed since is
        // left to that pass: it has rows to show meanwhile. Run apart from the
        // view's task, so leaving the tab does not call the lookup off halfway.
        if Self.isFirstLook(page), !lookedUp.contains(format) {
            await Task { await lookUp(format) }.value
        }
        await askForAlertsIfWorthIt(format)
    }

    /// Whether the reader follows something in this format and none of it was
    /// ever looked up.
    static func isFirstLook(_ page: DiscoveryPage) -> Bool {
        page.followed > 0 && page.unwatched == page.followed
    }

    /// Look up on the web the sagas of that format never looked up.
    private func lookUp(_ format: ReleaseFormat) async {
        lookedUp.insert(format)
        isLookingUp = true
        defer { isLookingUp = false }
        do {
            show(try await DiscoverAPI.lookUp(format: format), in: format)
        } catch {
            guard !isCancellation(error) else { return }
            errorMessage = reportError(error)
        }
    }

    /// The tab appeared: the formats still showing last session's snapshot
    /// are brought up to date, the ones never loaded load, one after the
    /// other. The ones the server already answered ask nothing: every write
    /// posts the change notice this tab listens to.
    func loadOnAppear() async {
        for format in ReleaseFormat.allCases where !loaded.contains(format) {
            await load(format)
        }
    }

    /// A pull: both formats are asked again.
    func loadAll() async {
        for format in ReleaseFormat.allCases { await load(format) }
    }

    /// The library changed: the formats already loaded are asked again.
    func reload() async {
        for format in loaded { await load(format) }
    }

    /// Over rows already on screen, the new ones slide into place and push the
    /// others aside rather than the whole list redrawing at once.
    private func show(_ page: DiscoveryPage, in format: ReleaseFormat) {
        withAnimation(feed.rows[format] == nil ? nil : .smooth) {
            feed.rows[format] = page.rows
            feed.authors[format] = page.authors
        }
        saveSnapshot()
    }

    /// Everything on screen goes to disk, for the next launch to open on.
    private func saveSnapshot() {
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

