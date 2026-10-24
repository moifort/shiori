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

    @Test func dismissedDiscoveryIsToldThenTheStripAskedAgain() async {
        let calls = Calls()
        var client = HomeClient.preview
        client.dismissSuggestion = { id, reason in calls.record("dismiss \(id) \(reason)") }
        client.discoveries = {
            calls.record("discoveries")
            throw Boom()
        }
        let viewModel = HomeViewModel(client: client, caching: false)

        await viewModel.dismiss(.preview, reason: .disliked)

        #expect(calls.all == ["dismiss \(Suggestion.preview.id) disliked", "discoveries"])
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
