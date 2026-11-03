import Foundation
import Testing
@testable import Shiori

@MainActor
struct NewsViewModelTests {
    @Test func loadFillsTheFeedAndTheReleases() async {
        let viewModel = NewsViewModel(client: .preview, caching: false)

        await viewModel.loadOnAppear()

        #expect(viewModel.shownEvents.map(\.id) == FeedEvent.previews.map(\.id))
        #expect(viewModel.releases.count == UpcomingRelease.previews.count)
        #expect(viewModel.yearReleases.count == UpcomingRelease.previews.count)
        #expect(viewModel.narratorNews.count == 1)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func failureOverNothingIsShown() async {
        var client = NewsClient.preview
        client.feed = { _, _ in throw Boom() }
        let viewModel = NewsViewModel(client: client, caching: false)

        await viewModel.loadOnAppear()

        #expect(viewModel.events.isEmpty)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.isLoading == false)
    }

    @Test func failureOverRowsKeepsThem() async {
        let fails = Flag()
        var client = NewsClient.preview
        client.feed = { after, limit in
            if fails.isOn { throw Boom() }
            return CursorPage(FeedEvent.previews, limit: limit, after: after, cursor: \.id)
        }
        let viewModel = NewsViewModel(client: client, caching: false)
        await viewModel.load()
        fails.isOn = true

        await viewModel.load()

        #expect(viewModel.events.count == FeedEvent.previews.count)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func pagesAppendByCursorWithoutRepeats() async {
        var client = NewsClient.preview
        client.feed = { after, _ in
            CursorPage(FeedEvent.previews, limit: 2, after: after, cursor: \.id)
        }
        let viewModel = NewsViewModel(client: client, caching: false)
        await viewModel.load()
        #expect(viewModel.events.count == 2)
        #expect(viewModel.hasMore)

        await viewModel.loadMore()

        #expect(viewModel.events.map(\.id) == FeedEvent.previews.map(\.id))
        #expect(viewModel.hasMore == false)
    }

    @Test func aFailedPageIsRetryableAndKeepsTheRows() async {
        let fails = Flag()
        var client = NewsClient.preview
        client.feed = { after, _ in
            if after != nil, fails.isOn { throw Boom() }
            return CursorPage(FeedEvent.previews, limit: 2, after: after, cursor: \.id)
        }
        let viewModel = NewsViewModel(client: client, caching: false)
        await viewModel.load()
        fails.isOn = true

        await viewModel.loadMore()

        #expect(viewModel.pageFailed)
        #expect(viewModel.events.count == 2)
        fails.isOn = false
        await viewModel.loadMore()
        #expect(viewModel.pageFailed == false)
        #expect(viewModel.events.count == FeedEvent.previews.count)
    }

    @Test func aFormatPillNarrowsTheCalendar() async {
        let viewModel = NewsViewModel(client: .preview, caching: false)
        await viewModel.load()

        viewModel.format = .manga

        #expect(viewModel.shownReleases.allSatisfy { $0.format == .manga })
        #expect(viewModel.shownEvents.count == FeedEvent.previews.count)
    }

    @Test func openingAmisPutsItsDotOut() async {
        let viewModel = NewsViewModel(client: .preview, caching: false)
        await viewModel.load()
        #expect(viewModel.friendsHaveNews)

        viewModel.tab = .friends
        viewModel.tab = .releases

        #expect(viewModel.friendsHaveNews == false)
    }

    @Test func narratorNewsFailingLeavesTheRestOfThePage() async {
        var client = NewsClient.preview
        client.narratorNews = { throw Boom() }
        let viewModel = NewsViewModel(client: client, caching: false)

        await viewModel.load()

        #expect(viewModel.narratorNews.isEmpty)
        #expect(viewModel.events.count == FeedEvent.previews.count)
    }

    @Test func takingABookGreysItOutAtOnce() async {
        let viewModel = NewsViewModel(client: .preview, caching: false)
        await viewModel.load()
        let event = viewModel.shownEvents.first { !$0.inLibrary }
        #expect(event != nil)

        await viewModel.take(event!, as: .book)

        #expect(viewModel.shownEvents.first { $0.id == event!.id }?.inLibrary == true)
    }

    @Test func invitingHandsTheInvitationOver() async {
        let viewModel = NewsViewModel(client: .preview, caching: false)

        await viewModel.invite()

        #expect(viewModel.invitation != nil)
    }
}
