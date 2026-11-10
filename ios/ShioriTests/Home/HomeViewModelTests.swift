import Foundation
import Testing
@testable import Shiori

@MainActor
struct HomeViewModelTests {
    @Test func loadShowsTheDashboardAndItsReleases() async {
        let viewModel = HomeViewModel(client: .preview, caching: false)
        #expect(viewModel.dashboard == nil)

        await viewModel.loadOnAppear()

        #expect(viewModel.dashboard != nil)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isLoading == false)
    }

    @Test func seenReleaseStaysUntilThePageIsLeftThenStaysAway() async {
        let suite = "home-seen-\(UUID().uuidString)"
        let store = SeenReleases(defaults: { UserDefaults(suiteName: suite)! })
        let viewModel = HomeViewModel(client: .preview, caching: false, seenStore: store)
        let release = HomeRelease.volume(.preview)

        viewModel.see(release)
        #expect(viewModel.hiddenReleases.isEmpty)
        #expect(store.all == [release.id])

        await viewModel.releaseTaken()
        #expect(viewModel.hiddenReleases == [release.id])

        viewModel.unsee(release)
        #expect(viewModel.hiddenReleases.isEmpty)
        #expect(store.all.isEmpty)
    }

    @Test func failureOverNothingIsSaid() async {
        var client = HomeClient.preview
        client.dashboard = { throw Boom() }
        let viewModel = HomeViewModel(client: client, caching: false)

        await viewModel.load()

        #expect(viewModel.dashboard == nil)
        #expect(viewModel.errorMessage != nil)
    }

    @Test func failureOverFiguresKeepsThem() async {
        let fails = Flag()
        var client = HomeClient.preview
        client.dashboard = {
            if fails.isOn { throw Boom() }
            return .preview
        }
        let viewModel = HomeViewModel(client: client, caching: false)
        await viewModel.load()

        fails.isOn = true
        await viewModel.load()

        #expect(viewModel.dashboard != nil)
    }

    /// Back from the background, the reload takes a few seconds: a pull in
    /// the meantime, or a write's notice, waits for it and asks once more,
    /// rather than returning at once over the figures still on screen.
    @Test func reloadAskedDuringALoadWaitsForItAndAsksAgain() async {
        let calls = Calls()
        let answered = Flag()
        var client = HomeClient.preview
        client.dashboard = {
            calls.record("dashboard")
            while !answered.isOn { try await Task.sleep(for: .milliseconds(10)) }
            return .preview
        }
        let viewModel = HomeViewModel(client: client, caching: false)
        let onReturn = Task { await viewModel.load() }
        await eventually { calls.all.count == 1 }

        let pull = Task { await viewModel.load() }
        try? await Task.sleep(for: .milliseconds(50))
        answered.isOn = true
        await pull.value

        #expect(calls.all == ["dashboard", "dashboard"])
        #expect(viewModel.isLoading == false)
        await onReturn.value
    }

    /// Between midnight and the server's own midnight (UTC) the server still
    /// says an edition out today is announced: it must lead the line anyway.
    @Test func editionOutTodayStaysWhileTheServerStillSaysAnnounced() async {
        let today = Date.now.formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day())
        let base = AwaitedEdition.preview
        let edition = AwaitedEdition(
            id: base.id, format: base.format, state: .announced, title: base.title,
            originalTitle: base.originalTitle, originalLanguage: base.originalLanguage,
            authors: base.authors, date: today, coverURL: nil, storeURL: base.storeURL,
            awaitedAt: base.awaitedAt, bookId: base.bookId, ownerId: base.ownerId
        )
        var client = HomeClient.preview
        client.awaited = { format in format == .audiobook ? [edition] : [] }
        let viewModel = HomeViewModel(client: client, caching: false)

        await viewModel.load()

        #expect(viewModel.releases.contains { $0.id == HomeRelease.awaited(edition).id })
    }

    @Test func releasesLeftOutWhenAFormatCannotBeRead() async {
        var client = HomeClient.preview
        client.discovery = { format in
            guard format == .book else { throw Boom() }
            return DiscoveryPage(rows: [.preview], authors: [], unwatched: 0, followed: 1)
        }
        let viewModel = HomeViewModel(client: client, caching: false)

        await viewModel.load()

        #expect(viewModel.releases.isEmpty)
        #expect(viewModel.dashboard != nil)
    }

    /// The opening asks the dashboard and the discoveries in one request, and
    /// the releases' four sections in another: none of them alone.
    @Test func openingAsksTwoComposedRequests() async {
        let calls = Calls()
        var client = HomeClient.preview
        client.dashboard = { calls.record("dashboard"); return .preview }
        client.discoveries = { calls.record("discoveries"); return .preview }
        client.discovery = { _ in calls.record("discovery"); throw Boom() }
        client.awaited = { _ in calls.record("awaited"); return [] }
        client.opening = { HomeOpening(dashboard: .preview, discoveries: .preview) }
        let edition = Self.editionOutToday
        client.releaseSources = {
            HomeReleaseSources(
                books: DiscoveryPage(rows: [.preview], authors: [], unwatched: 0, followed: 1),
                audiobooks: DiscoveryPage(rows: [], authors: [], unwatched: 0, followed: 0),
                awaited: [edition]
            )
        }
        let viewModel = HomeViewModel(client: client, caching: false)

        await viewModel.load()

        #expect(calls.all.isEmpty)
        #expect(viewModel.dashboard != nil)
        #expect(viewModel.discoveries == .preview)
        #expect(viewModel.releases.contains { $0.id == HomeRelease.awaited(edition).id })
    }

    /// A field in error loses the whole composed answer: each section is then
    /// asked alone, and the ones that answer are still drawn.
    @Test func composedFieldInErrorAsksEachSectionAlone() async {
        var client = HomeClient.preview
        client.opening = { throw APIError.graphQL(messages: ["monthlyDiscoveries failed"]) }
        client.releaseSources = { throw APIError.graphQL(messages: ["awaitedEditions failed"]) }
        let edition = Self.editionOutToday
        client.awaited = { format in
            guard format == .audiobook else { throw Boom() }
            return [edition]
        }
        let viewModel = HomeViewModel(client: client, caching: false)

        await viewModel.load()

        #expect(viewModel.dashboard != nil)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.releases.contains { $0.id == HomeRelease.awaited(edition).id })
    }

    /// An edition awaited out today, which always leads the line.
    private static var editionOutToday: AwaitedEdition {
        let today = Date.now.formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day())
        let base = AwaitedEdition.preview
        return AwaitedEdition(
            id: base.id, format: base.format, state: .announced, title: base.title,
            originalTitle: base.originalTitle, originalLanguage: base.originalLanguage,
            authors: base.authors, date: today, coverURL: nil, storeURL: base.storeURL,
            awaitedAt: base.awaitedAt, bookId: base.bookId, ownerId: base.ownerId
        )
    }

    /// Offline, the sections are not asked one by one: they would only fail
    /// as many times.
    @Test func composedNetworkFailureIsNotAskedAgainBySection() async {
        let calls = Calls()
        var client = HomeClient.preview
        client.dashboard = { calls.record("dashboard"); return .preview }
        client.discovery = { _ in calls.record("discovery"); throw Boom() }
        client.opening = { throw URLError(.notConnectedToInternet) }
        client.releaseSources = { throw URLError(.notConnectedToInternet) }
        let viewModel = HomeViewModel(client: client, caching: false)

        await viewModel.load()

        #expect(calls.all.isEmpty)
        #expect(viewModel.dashboard == nil)
    }

    @Test func monthWithoutItsSelectionGetsOneMadeOnceTheShelfIsKnown() async {
        let calls = Calls()
        let month = MonthlyDiscoveries.month(of: .now)
        var client = HomeClient.preview
        client.discoveries = {
            calls.record("read")
            return MonthlyDiscoveries(month: month, status: .none, suggestions: [])
        }
        client.lookUpDiscoveries = {
            calls.record("lookUp")
            return MonthlyDiscoveries(month: month, status: .ready, suggestions: [.preview])
        }
        let viewModel = HomeViewModel(client: client, caching: false)

        await viewModel.load()
        await eventually { viewModel.discoveries?.status == .ready }

        #expect(calls.all.contains("lookUp"))
        #expect(viewModel.isSearchingDiscoveries == false)
    }

    @Test func selectionIsNotAskedBeforeTheFirstBook() async {
        let calls = Calls()
        var client = HomeClient.preview
        client.dashboard = { .empty }
        client.discoveries = { MonthlyDiscoveries(month: MonthlyDiscoveries.month(of: .now), status: .none, suggestions: []) }
        client.lookUpDiscoveries = {
            calls.record("lookUp")
            return .preview
        }
        let viewModel = HomeViewModel(client: client, caching: false)

        await viewModel.load()
        await viewModel.loadDiscoveries()

        #expect(calls.all.isEmpty)
    }

    @Test func selectionAlreadyMadeIsNotAskedAgain() async {
        let calls = Calls()
        var client = HomeClient.preview
        client.discoveries = { MonthlyDiscoveries(month: MonthlyDiscoveries.month(of: .now), suggestions: [.preview]) }
        client.lookUpDiscoveries = {
            calls.record("lookUp")
            return .preview
        }
        let viewModel = HomeViewModel(client: client, caching: false)

        await viewModel.load()
        await viewModel.loadDiscoveries()

        #expect(calls.all.isEmpty)
    }

    @Test func takenDiscoveryStaysUntilThePageIsLeft() async {
        let full = MonthlyDiscoveries.preview
        let taken = full.suggestions[1]
        let gone = Flag()
        var client = HomeClient.preview
        // Once added, the server leaves the book out of the month's line.
        client.discoveries = {
            gone.isOn
                ? MonthlyDiscoveries(month: full.month, suggestions: full.suggestions.filter { $0.id != taken.id })
                : full
        }
        let viewModel = HomeViewModel(client: client, caching: false)
        await viewModel.loadDiscoveries()

        viewModel.hold(taken)
        gone.isOn = true
        await viewModel.loadDiscoveries()

        #expect(viewModel.discoveries?.suggestions.map(\.id) == full.suggestions.map(\.id))

        await viewModel.releaseTaken()

        #expect(viewModel.discoveries?.suggestions.contains { $0.id == taken.id } == false)
    }

    @Test func alreadyReadTakenBackLeavesTheShelf() async {
        let calls = Calls()
        var client = HomeClient.preview
        client.addBook = { draft in
            calls.record("add \(draft.status)")
            return "book-1"
        }
        client.deleteBook = { calls.record("delete \($0)") }
        let viewModel = HomeViewModel(client: client, caching: false)
        let suggestion = Suggestion.preview

        #expect(await viewModel.choose(suggestion, .alreadyRead))
        #expect(await viewModel.choose(suggestion, .undoAlreadyRead))

        #expect(calls.all == ["add \(ReadingStatus.read)", "delete book-1"])
    }

    @Test func refusedChoiceIsSaidAndAnsweredFalse() async {
        struct Refused: Error {}
        var client = HomeClient.preview
        client.addBook = { _ in throw Refused() }
        let viewModel = HomeViewModel(client: client, caching: false)

        #expect(await viewModel.choose(.preview, .alreadyRead) == false)
        #expect(viewModel.actionError != nil)
    }
}

@MainActor
struct AdminViewModelTests {
    @Test func failureIsSaid() async {
        let viewModel = AdminViewModel(client: AdminClient(metrics: { throw Boom() }))

        await viewModel.load()

        #expect(viewModel.metrics == nil)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.isLoading == false)
    }
}
