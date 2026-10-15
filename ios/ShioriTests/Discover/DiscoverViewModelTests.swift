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
}

@MainActor
struct AnnouncedVolumeViewModelTests {
    @Test func aRecordingWithoutAudibleIsAddedFromItsPage() async {
        let calls = Calls()
        var client = DiscoverClient.preview
        client.addAudibleVolume = { _, _, _ in
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
        client.addAudibleVolume = { _, _, _ in throw APIError.domain(code: "NOT_FOUND", messages: []) }
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
