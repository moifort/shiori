import Foundation
import SwiftUI

/// Owns the Découvrir tab's rows, one list per format drawn mixed, and the
/// one in-flight load. The tab opens on everything it last showed — the rows, the friends'
/// picks and the editions awaited: a `SnapshotCache` hands them back from disk
/// before a byte is asked of the network, and the fetches bring them up to
/// date silently underneath, the new rows sliding into place.
///
/// Every section loads through one `LoadGate`: the appearance, the change
/// notices and the sheets closing all ask for the same sections, and each
/// used to send its own request beside the one already on its way.
@MainActor
@Observable
final class DiscoverViewModel {
    init(client: DiscoverClient, snapshots: DiscoverSnapshots = .disk) {
        self.client = client
        self.snapshots = snapshots
        feed = snapshots.feed?.read() ?? DiscoveryFeed()
        discoveries = snapshots.discoveries?.read()
        awards = snapshots.awards?.read() ?? [:]
    }

    private let client: DiscoverClient
    private let snapshots: DiscoverSnapshots

    private(set) var feed: DiscoveryFeed
    /// The rows of a format are being asked for.
    var isLoading: Bool { !rowsInFlight.isEmpty }
    private var rowsInFlight: Set<ReleaseFormat> = []
    private(set) var errorMessage: String?
    /// The first look at a format: everything the reader follows in it is
    /// being looked up on the web, and the tab has nothing to show until it is.
    private(set) var isLookingUp = false

    /// The sections a request may be on its way for.
    enum Section: Hashable {
        case rows(ReleaseFormat)
        case picks
        case awaited(ReleaseFormat)
        case awards(ReleaseFormat)
        case discoveries(ReleaseFormat)
    }

    private let gate = LoadGate<Section>()
    /// The sections the server has answered for since launch, so they are no
    /// longer the snapshot. A discoveries line counts once its selection is
    /// made: one left searching is asked again on the next appearance.
    private var answered: Set<Section> = []
    /// The formats whose rows the server has answered for.
    private var loaded: [ReleaseFormat] { ReleaseFormat.allCases.filter { answered.contains(.rows($0)) } }
    /// The formats already looked up this session: a lookup that left sagas
    /// behind — out of budget, or failed — is not started again on every
    /// look, and the hourly pass takes the rest.
    private var lookedUp: Set<ReleaseFormat> = []

    /// The sagas of both formats, nil until neither format was ever loaded.
    var rows: [SagaDiscovery]? { feed.sagas }

    /// "Coups de cœur de vos amis", whatever the format: last session's until
    /// loaded, and last load's when a later one fails — the section is a
    /// suggestion, not worth an error of its own.
    var picks: FriendPicks { feed.picks }

    func loadPicks() async {
        await gate.run(.picks, again: true) { await fetchPicks() }
    }

    private func fetchPicks() async {
        do {
            let found = try await client.picks()
            withAnimation(.smooth) { feed.picks = found }
            markAnswered(.picks)
            saveSnapshot()
        } catch {
            _ = reportError(error)
        }
    }

    /// "Bientôt disponible": the editions awaited in both formats — last
    /// session's until loaded, and last load's when a later one fails, as the
    /// friends' picks.
    var awaitedSoon: [AwaitedEdition] { feed.awaitedSoon }

    func loadAwaited(_ format: ReleaseFormat) async {
        await gate.run(.awaited(format), again: true) { await fetchAwaited(format) }
    }

    private func fetchAwaited(_ format: ReleaseFormat) async {
        do {
            let found = try await client.awaited(format)
            withAnimation(.smooth) { feed.awaited[format] = found }
            markAnswered(.awaited(format))
            saveSnapshot()
        } catch {
            guard !isCancellation(error) else { return }
            _ = reportError(error)
        }
    }

    /// The award winners in each format, one section per genre the reader
    /// reads most: empty until loaded, and when the reader reads no genre with
    /// awards enough. Kept on disk so the line opens with the tab rather than
    /// sliding in seconds later, and asked anew on each write.
    private(set) var awards: [ReleaseFormat: [AwardSection]] = [:]

    /// The format the award winners and the month's discoveries are shown in.
    var awardsFormat: ReleaseFormat { feed.awardsFormat }

    /// The award winners of the format shown.
    var shownAwards: [AwardSection] { awards[awardsFormat] ?? [] }

    func loadAwards(_ format: ReleaseFormat) async {
        await gate.run(.awards(format), again: true) { await fetchAwards(format) }
    }

    private func fetchAwards(_ format: ReleaseFormat) async {
        do {
            let found = try await client.awards(format)
            withAnimation(.smooth) { awards[format] = found }
            markAnswered(.awards(format))
            if let cache = snapshots.awards {
                let kept = awards
                Task.detached { cache.write(kept) }
            }
        } catch {
            guard !isCancellation(error) else { return }
            _ = reportError(error)
        }
    }

    /// The month's discoveries as last shown, kept on disk so the line opens
    /// on them: the books chosen for the reader, each with why.
    private(set) var discoveries: MonthlyDiscoveries?
    /// The month's selection is being made: the first look of a month waits
    /// for the model, about a minute.
    private(set) var isLookingUpDiscoveries = false

    /// What the line draws: the month's covers, the search under way, the
    /// month's selection run out — or nothing, when the month has none.
    var discoveriesLine: DiscoveriesLine? {
        let month = MonthlyDiscoveries.month(of: .now)
        guard let discoveries, discoveries.month == month else {
            return isLookingUpDiscoveries ? .searching(month: month) : nil
        }
        switch discoveries.status {
        case .ready:
            return discoveries.suggestions.isEmpty ? .ranOut(discoveries) : .shown(discoveries)
        case .searching:
            return .searching(month: month)
        case .none:
            return isLookingUpDiscoveries ? .searching(month: month) : nil
        }
    }

    /// How often a look that found the selection being made asks again, and
    /// for how long at most: a generation runs about a minute and a half.
    private static let searchPoll: Duration = .seconds(5)
    private static let searchPolls = 40

    /// Asks for the month's discoveries, making the selection when the month
    /// has none yet. A look that finds it being made — Découvrir asks again as
    /// it settles — waits for it, asking every few seconds.
    func loadDiscoveries(_ format: ReleaseFormat) async {
        await gate.run(.discoveries(format), again: true) { await fetchDiscoveries(format) }
    }

    private func fetchDiscoveries(_ format: ReleaseFormat) async {
        isLookingUpDiscoveries = true
        defer { isLookingUpDiscoveries = false }
        // A request given up on while the server still makes the selection
        // — a slow generation outlasting the app's wait — is asked again a
        // few times before the failure is reported.
        var failures = 0
        for _ in 0..<Self.searchPolls {
            do {
                let found = try await client.discoveries(format)
                withAnimation(.smooth) { discoveries = found }
                guard found.status == .searching else {
                    markAnswered(.discoveries(format))
                    if let cache = snapshots.discoveries { Task.detached { cache.write(found) } }
                    return
                }
            } catch {
                guard !isCancellation(error) else { return }
                failures += 1
                guard failures < 3 else {
                    _ = reportError(error)
                    return
                }
            }
            do { try await Task.sleep(for: Self.searchPoll) } catch { return }
        }
    }

    /// "Pas intéressé" or "Je n'aime pas": the row leaves at once, and the line is asked again
    /// for the next suggestion once the server took note. Put back if it
    /// refused.
    func dismiss(_ suggestion: Suggestion, reason: DismissalReason, format: ReleaseFormat) async {
        let before = discoveries
        withAnimation(.smooth) {
            discoveries = discoveries.map { current in
                MonthlyDiscoveries(
                    month: current.month,
                    suggestions: current.suggestions.filter { $0.id != suggestion.id }
                )
            }
        }
        do {
            try await client.dismissSuggestion(suggestion.id, reason)
            await loadDiscoveries(format)
        } catch {
            withAnimation(.smooth) { discoveries = before }
            errorMessage = reportError(error)
        }
    }

    /// Every format already shown is asked again.
    func reloadAwaited() async {
        for format in ReleaseFormat.allCases where feed.awaited[format] != nil { await loadAwaited(format) }
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
            try await client.stopAwaiting(edition.id)
            saveSnapshot()
        } catch {
            withAnimation(.smooth) {
                feed.awaited[edition.format] = before
                feed.authors[edition.format] = authorsBefore
            }
            errorMessage = reportError(error)
        }
    }

    func load(_ format: ReleaseFormat) async {
        await gate.run(.rows(format), again: true) { await fetchRows(format) }
    }

    private func fetchRows(_ format: ReleaseFormat) async {
        rowsInFlight.insert(format)
        errorMessage = nil
        let page: DiscoveryPage
        do {
            page = try await client.discovery(format)
            feed.followed[format] = page.followed
            show(page, in: format)
            markAnswered(.rows(format))
        } catch {
            rowsInFlight.remove(format)
            guard !isCancellation(error) else { return }
            // The last rows stay on screen and say nothing: blanking good rows
            // because a refresh failed reads as data loss, and a pull tries again.
            errorMessage = reportError(error)
            return
        }
        rowsInFlight.remove(format)
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
            show(try await client.lookUp(format), in: format)
        } catch {
            guard !isCancellation(error) else { return }
            errorMessage = reportError(error)
        }
    }

    /// The tab appeared: every section still showing last session's snapshot
    /// is brought up to date, every one never loaded loads — each once, the
    /// rows of the two formats one after the other. The sections the server
    /// already answered ask nothing: every write posts the change notice this
    /// tab listens to. Only the bell is read on each appearance, the system
    /// setting being changed outside the app.
    func loadOnAppear() async {
        async let alerts: Void = loadAlerts()
        async let picks: Void = loadIfMissing(.picks)
        async let printed: Void = loadIfMissing(.awaited(.book))
        async let recorded: Void = loadIfMissing(.awaited(.audiobook))
        // Over last session's rows the format shown is known at once; over
        // nothing, it waits for the rows to say which one the reader holds.
        let overSnapshot = feed.sagas != nil
        async let shown: Void = overSnapshot ? loadShownIfMissing() : ()
        for format in ReleaseFormat.allCases { await loadIfMissing(.rows(format)) }
        await shown
        // The rows may have moved the format shown.
        await loadShownIfMissing()
        _ = await (alerts, picks, printed, recorded)
    }

    /// A pull: the rows of both formats and the friends' picks are asked
    /// again, and the award winners and the month's discoveries of a format
    /// the rows just moved to.
    func refresh() async {
        async let picks: Void = loadPicks()
        await loadAll()
        await loadShownIfMissing()
        await picks
    }

    /// Both formats are asked again, one after the other.
    func loadAll() async {
        for format in ReleaseFormat.allCases { await load(format) }
    }

    /// The library changed: the formats already loaded are asked again.
    func reload() async {
        for format in loaded { await load(format) }
    }

    /// A write landed anywhere: the rows, the friends' picks, and the award
    /// winners and the month's discoveries, which leave out what the reader
    /// now holds.
    func libraryChanged() async {
        await reload()
        await loadPicks()
        await loadShown()
    }

    /// An edition was awaited or given up: the Authors shelf carries them too.
    func awaitedChanged() async {
        await reloadAwaited()
        await reload()
        await loadShown()
    }

    /// The award winners and the month's discoveries of the format shown,
    /// asked again.
    func loadShown() async {
        await loadAwards(awardsFormat)
        await loadDiscoveries(awardsFormat)
    }

    private func loadShownIfMissing() async {
        let format = awardsFormat
        async let awards: Void = loadIfMissing(.awards(format))
        await loadIfMissing(.discoveries(format))
        await awards
    }

    /// A write that landed while the answer was on its way leaves the section
    /// unanswered: the load runs again for it, and should a departure from the
    /// tab call that off, the next appearance asks.
    private func markAnswered(_ section: Section) {
        guard !gate.isStale(section) else { return }
        answered.insert(section)
    }

    /// Loads a section the server never answered for, unless a request for
    /// it is already on its way.
    private func loadIfMissing(_ section: Section) async {
        guard !answered.contains(section) else { return }
        await gate.run(section, again: false) {
            switch section {
            case let .rows(format): await fetchRows(format)
            case .picks: await fetchPicks()
            case let .awaited(format): await fetchAwaited(format)
            case let .awards(format): await fetchAwards(format)
            case let .discoveries(format): await fetchDiscoveries(format)
            }
        }
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
        guard let cache = snapshots.feed else { return }
        let snapshot = feed
        Task.detached { cache.write(snapshot) }
    }

    /// The alert is on by default, but the system asks once: the first time
    /// the tab has a volume to announce, which is when saying yes means
    /// something. Asked once, the system never shows it again.
    private func askForAlertsIfWorthIt(_ format: ReleaseFormat) async {
        guard feed.rows[format]?.contains(where: { $0.releases.next != nil }) == true else { return }
        await client.requestAlerts()
    }

    /// Whether the bell is struck through: nothing can reach the reader.
    private(set) var alertsSilenced = false

    /// Asked when the tab appears and when the alerts sheet closes.
    func loadAlerts() async {
        alertsSilenced = await client.alertsSilenced()
    }
}

/// Where Découvrir keeps what it last showed: on disk in the app, nowhere in
/// a test.
struct DiscoverSnapshots: Sendable {
    /// Bump the version whenever `DiscoveryFeed` changes shape.
    var feed: SnapshotCache<DiscoveryFeed>?
    /// Bump the version whenever `AwardSection` changes shape.
    var awards: SnapshotCache<[ReleaseFormat: [AwardSection]]>?
    /// Bump the version whenever `MonthlyDiscoveries` changes shape.
    var discoveries: SnapshotCache<MonthlyDiscoveries>?

    static let disk = DiscoverSnapshots(
        feed: SnapshotCache("discovery", version: 8),
        awards: SnapshotCache("discover-awards", version: 1),
        discoveries: SnapshotCache("discover-discoveries", version: 2)
    )

    static let none = DiscoverSnapshots()
}

/// What Découvrir's discoveries line draws.
enum DiscoveriesLine {
    /// The month's covers.
    case shown(MonthlyDiscoveries)
    /// The month's selection is being made.
    case searching(month: String)
    /// Every book of the month's selection was taken or set aside: the next
    /// month brings new ones.
    case ranOut(MonthlyDiscoveries)
}
