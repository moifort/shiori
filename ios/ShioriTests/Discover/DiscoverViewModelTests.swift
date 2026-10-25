import Foundation
import Testing
@testable import Shiori

@MainActor
struct DiscoverViewModelTests {
    @Test func loadShowsBothFormatsMixed() async {
        let viewModel = DiscoverViewModel(client: .preview, snapshots: .none)
        #expect(viewModel.rows == nil)

        await viewModel.loadOnAppear()

        #expect(viewModel.rows?.map(\.id) == DiscoveryFeed.preview.sagas?.map(\.id))
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func failureOverNothingIsShown() async {
        var client = DiscoverClient.preview
        client.discovery = { _ in throw Boom() }
        let viewModel = DiscoverViewModel(client: client, snapshots: .none)

        await viewModel.loadOnAppear()

        #expect(viewModel.rows == nil)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.isLoading == false)
    }

    @Test func failureOverContentKeepsTheRows() async {
        let fails = Flag()
        var client = DiscoverClient.preview
        client.discovery = { format in
            if fails.isOn { throw Boom() }
            return DiscoveryFeed.preview.page(format)
        }
        let viewModel = DiscoverViewModel(client: client, snapshots: .none)
        await viewModel.loadAll()
        let shown = viewModel.rows?.map(\.id)

        fails.isOn = true
        await viewModel.loadAll()

        #expect(shown?.isEmpty == false)
        #expect(viewModel.rows?.map(\.id) == shown)
    }

    @Test func cancellationIsNoFailure() async {
        var client = DiscoverClient.preview
        client.discovery = { _ in throw CancellationError() }
        let viewModel = DiscoverViewModel(client: client, snapshots: .none)

        await viewModel.loadOnAppear()

        #expect(viewModel.errorMessage == nil)
    }

    @Test func firstLookLooksEverythingUp() async {
        let calls = Calls()
        var client = DiscoverClient.preview
        client.discovery = { format in
            let page = DiscoveryFeed.preview.page(format)
            return DiscoveryPage(rows: [], authors: [], unwatched: page.followed, followed: page.followed)
        }
        client.lookUp = { format in
            calls.record("lookUp \(format)")
            return DiscoveryFeed.preview.page(format)
        }
        let viewModel = DiscoverViewModel(client: client, snapshots: .none)

        await viewModel.loadOnAppear()

        #expect(calls.all == ["lookUp book", "lookUp audiobook"])
        #expect(viewModel.rows?.count == 2)
        #expect(viewModel.isLookingUp == false)
    }

    @Test func stopAwaitingTakesTheEditionOff() async {
        let calls = Calls()
        var client = DiscoverClient.preview
        client.stopAwaiting = { calls.record("stop \($0)") }
        let viewModel = DiscoverViewModel(client: client, snapshots: .none)
        await viewModel.loadAll()
        await viewModel.loadAwaited(.audiobook)
        #expect(viewModel.awaitedSoon.map(\.id) == [AwaitedEdition.preview.id])

        await viewModel.stopAwaiting(.preview)

        #expect(calls.all == ["stop \(AwaitedEdition.preview.id)"])
        #expect(viewModel.awaitedSoon.isEmpty)
        #expect(viewModel.feed.authors[.audiobook]?.first?.awaited.isEmpty == true)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func aScanAwaitedShowsItsTileAtOnceThenTheServersEdition() async {
        let draft = BookDraft(title: "Project Hail Mary", authors: ["Andy Weir"], format: .book)
        var client = DiscoverClient.preview
        client.awaitEdition = { _, _ in
            try await Task.sleep(for: .seconds(30))
            return .preview
        }
        let viewModel = DiscoverViewModel(client: client, snapshots: .none)

        let asked = Task { await viewModel.awaitScanned(AwaitRequest(draft: draft, format: .audiobook)) }
        while viewModel.awaitedSoon.isEmpty { await Task.yield() }

        let pending = viewModel.awaitedSoon.first
        #expect(pending?.title == "Project Hail Mary")
        #expect(pending?.format == .audiobook)
        #expect(viewModel.focusedAwaited == pending?.id)

        // Cancelled, the request is refused: the tile goes again.
        asked.cancel()
        await asked.value
        #expect(viewModel.awaitedSoon.isEmpty)
        #expect(viewModel.focusedAwaited == nil)
    }

    @Test func aScanAwaitedIsFocusedOnTheServersEdition() async {
        let draft = BookDraft(title: "Project Hail Mary", authors: ["Andy Weir"], format: .book)
        var client = DiscoverClient.preview
        client.awaitEdition = { _, _ in .preview }
        let viewModel = DiscoverViewModel(client: client, snapshots: .none)

        await viewModel.awaitScanned(AwaitRequest(draft: draft, format: .audiobook))

        #expect(viewModel.awaitedSoon.map(\.id) == [AwaitedEdition.preview.id])
        #expect(viewModel.focusedAwaited == AwaitedEdition.preview.id)
    }

    @Test func stopAwaitingRefusedPutsItBack() async {
        var client = DiscoverClient.preview
        client.stopAwaiting = { _ in throw Boom() }
        let viewModel = DiscoverViewModel(client: client, snapshots: .none)
        await viewModel.loadAll()
        await viewModel.loadAwaited(.audiobook)

        await viewModel.stopAwaiting(.preview)

        #expect(viewModel.awaitedSoon.map(\.id) == [AwaitedEdition.preview.id])
        #expect(viewModel.feed.authors[.audiobook]?.first?.awaited.map(\.id) == [AwaitedEdition.preview.id])
        #expect(viewModel.errorMessage != nil)
    }

    @Test func awardsFollowWhatTheReaderHolds() async {
        var client = DiscoverClient.preview
        client.discovery = { format in
            format == .book
                ? DiscoveryPage(rows: [], authors: [], unwatched: 0, followed: 0)
                : DiscoveryFeed.preview.page(format)
        }
        let viewModel = DiscoverViewModel(client: client, snapshots: .none)

        await viewModel.loadAll()

        #expect(viewModel.awardsFormat == .audiobook)
    }

    @Test func alertsSilencedIsRead() async {
        var client = DiscoverClient.preview
        client.alertsSilenced = { true }
        let viewModel = DiscoverViewModel(client: client, snapshots: .none)

        await viewModel.loadAlerts()

        #expect(viewModel.alertsSilenced)
    }

    // MARK: One request per section

    @Test func anAppearanceAsksEachSectionOnce() async {
        let requests = Requests()
        let viewModel = DiscoverViewModel(client: .counting(requests), snapshots: .none)

        await viewModel.loadOnAppear()

        #expect(requests.counts == [
            "alerts": 1, "awaited book": 1, "awaited audiobook": 1, "awards book": 1,
            "discoveries book": 1, "discovery book": 1, "discovery audiobook": 1, "picks": 1,
        ])
        #expect(requests.mostAtOnce <= 1)
    }

    @Test func comingBackAsksOnlyTheBell() async {
        let requests = Requests()
        let viewModel = DiscoverViewModel(client: .counting(requests), snapshots: .none)
        await viewModel.loadOnAppear()
        requests.reset()

        await viewModel.loadOnAppear()

        #expect(requests.counts == ["alerts": 1])
    }

    @Test func aSectionThatFailedIsAskedOnTheNextAppearance() async {
        let requests = Requests()
        let fails = Flag()
        fails.isOn = true
        var client = DiscoverClient.counting(requests)
        let awards = client.awards
        client.awards = { format in
            if fails.isOn { throw Boom() }
            return try await awards(format)
        }
        let viewModel = DiscoverViewModel(client: client, snapshots: .none)
        await viewModel.loadOnAppear()
        fails.isOn = false
        requests.reset()

        await viewModel.loadOnAppear()

        #expect(requests.counts == ["alerts": 1, "awards book": 1])
    }

    @Test func aNoticeDuringTheAppearanceNeverAsksTwiceAtOnce() async {
        let requests = Requests()
        let viewModel = DiscoverViewModel(client: .counting(requests), snapshots: .none)

        async let appeared: Void = viewModel.loadOnAppear()
        async let changed: Void = viewModel.libraryChanged()
        async let awaited: Void = viewModel.awaitedChanged()
        _ = await (appeared, changed, awaited)

        #expect(requests.mostAtOnce <= 1)
        #expect(viewModel.isLoading == false)
    }

    @Test func aWriteWhileALoadRunsAsksOnceMoreAfterIt() async {
        let requests = Requests()
        let viewModel = DiscoverViewModel(client: .counting(requests), snapshots: .none)
        await viewModel.loadOnAppear()
        requests.reset()

        async let first: Void = viewModel.loadDiscoveries(.book)
        async let second: Void = viewModel.loadDiscoveries(.book)
        async let third: Void = viewModel.loadDiscoveries(.book)
        _ = await (first, second, third)

        #expect(requests.counts == ["discoveries book": 2])
        #expect(requests.mostAtOnce == 1)
    }

    @Test func aWriteAsksTheSectionsItMoves() async {
        let requests = Requests()
        let viewModel = DiscoverViewModel(client: .counting(requests), snapshots: .none)
        await viewModel.loadOnAppear()
        requests.reset()

        await viewModel.libraryChanged()

        #expect(requests.counts == [
            "awards book": 1, "discoveries book": 1, "discovery book": 1, "discovery audiobook": 1, "picks": 1,
        ])
    }
}

/// Every request a client was sent, by name, and how many of the same ran at
/// once at most.
final class Requests: @unchecked Sendable {
    private let lock = NSLock()
    private var sent: [String: Int] = [:]
    private var running: [String: Int] = [:]
    private var most = 0

    var counts: [String: Int] { lock.withLock { sent } }
    var mostAtOnce: Int { lock.withLock { most } }

    func reset() { lock.withLock { sent = [:]; most = 0 } }

    /// Runs the request a little while, long enough for another to overlap it.
    func record<Value>(_ name: String, _ answer: () async throws -> Value) async rethrows -> Value {
        lock.withLock {
            sent[name, default: 0] += 1
            running[name, default: 0] += 1
            most = max(most, running[name] ?? 0)
        }
        defer { lock.withLock { running[name, default: 0] -= 1 } }
        try? await Task.sleep(for: .milliseconds(20))
        return try await answer()
    }
}

extension DiscoverClient {
    /// The preview client, every read counted.
    static func counting(_ requests: Requests) -> DiscoverClient {
        let preview = DiscoverClient.preview
        var client = preview
        client.discovery = { format in try await requests.record("discovery \(format)") { try await preview.discovery(format) } }
        client.picks = { try await requests.record("picks") { try await preview.picks() } }
        client.awaited = { format in try await requests.record("awaited \(format)") { try await preview.awaited(format) } }
        client.awards = { format in try await requests.record("awards \(format)") { try await preview.awards(format) } }
        client.discoveries = { format in
            try await requests.record("discoveries \(format)") { try await preview.discoveries(format) }
        }
        client.alertsSilenced = { await requests.record("alerts") { await preview.alertsSilenced() } }
        return client
    }
}

@MainActor
struct AnnouncedVolumeViewModelTests {
    @Test func aRecordingWithoutAudibleIsAddedFromItsPage() async {
        let calls = Calls()
        var client = DiscoverClient.preview
        client.addAudibleVolume = { _, _ in
            throw APIError.domain(code: "AUDIBLE_NOT_CONNECTED", messages: [])
        }
        client.addBook = { draft in
            calls.record("add \(draft.title) #\(draft.series?.volume ?? 0)")
        }
        let viewModel = AnnouncedVolumeViewModel(opened: .preview, client: client)

        await viewModel.add()

        #expect(calls.all == ["add Le Livre du Carnage #8"])
        #expect(viewModel.added)
        #expect(viewModel.addFailed == nil)
    }

    @Test func aFailedAdditionIsSaid() async {
        var client = DiscoverClient.preview
        client.addAudibleVolume = { _, _ in throw APIError.domain(code: "NOT_FOUND", messages: []) }
        client.addBook = { _ in throw Boom() }
        let viewModel = AnnouncedVolumeViewModel(opened: .preview, client: client)

        await viewModel.add()

        #expect(viewModel.added == false)
        #expect(viewModel.addFailed != nil)
    }
}

struct DiscoveryShelvesTests {
    private func edition(_ id: String, state: AwaitedState, date: String?) -> AwaitedEdition {
        AwaitedEdition(
            id: id,
            format: .book,
            state: state,
            title: id,
            originalTitle: id,
            originalLanguage: .en,
            authors: [],
            date: date,
            coverURL: nil,
            storeURL: nil,
            awaitedAt: nil,
            bookId: "book",
            ownerId: "me"
        )
    }

    @Test func soonOrderPutsTheComingFirstThenTheNewestOut() {
        let editions = [
            edition("out-old", state: .available, date: "2026-01-10"),
            edition("coming-undated", state: .announced, date: nil),
            edition("coming-late", state: .announced, date: "2027"),
            edition("out-new", state: .available, date: "2026-09-01"),
            edition("coming-soon", state: .announced, date: "2027-02-19"),
        ]

        #expect(editions.soonOrder.map(\.id) == [
            "coming-soon", "coming-late", "coming-undated", "out-new", "out-old",
        ])
    }

    @Test func seriesNewsListsTheVolumesOutThenAnnounced() {
        let news = DiscoveryFeed.preview.seriesNews.map(\.volume.title)

        #expect(news == ["La Colère de Tiamat", "Les Jeux de Persépolis", "Le Livre du Carnage"])
    }

    @Test func aLookupKeepsWhatTheCallerDecided() {
        var draft = BookDraft(title: "Tome 3", authors: ["Autrice"], format: .audiobook, media: [])
        draft.series = SeriesMembership(id: "saga", name: "Saga", volume: 3, kind: .main)
        draft.status = .read
        var found = BookDraft(title: "", authors: [], format: .book, media: [.print])
        found.synopsis = "Trouvé"
        found.language = .en

        let merged = draft.completed(by: found)

        #expect(merged.title == "Tome 3")
        #expect(merged.authors == ["Autrice"])
        #expect(merged.format == .audiobook)
        #expect(merged.media.isEmpty)
        #expect(merged.series?.volume == 3)
        #expect(merged.status == .read)
        #expect(merged.synopsis == "Trouvé")
        #expect(merged.language == .en)
    }
}
