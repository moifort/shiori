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
