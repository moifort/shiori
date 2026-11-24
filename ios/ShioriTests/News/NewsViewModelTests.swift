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

    @Test func aFormatPillNarrowsTheFeedButKeepsTheOtherPills() async {
        let viewModel = NewsViewModel(client: .preview, caching: false)
        await viewModel.load()
        let pills = viewModel.pillFormats()

        viewModel.format = .manga

        #expect(viewModel.feedSections().flatMap(\.items).allSatisfy { $0.format == .manga })
        #expect(viewModel.shownEvents.count == FeedEvent.previews.count)
        #expect(viewModel.pillFormats() == pills)
    }

    @Test func narratorNewsFailingLeavesTheRestOfThePage() async {
        var client = NewsClient.preview
        client.narratorNews = { throw Boom() }
        let viewModel = NewsViewModel(client: client, caching: false)

        await viewModel.load()

        #expect(viewModel.narratorNews.isEmpty)
        #expect(viewModel.events.count == FeedEvent.previews.count)
    }

    /// The opening is one request for every section, none asked alone.
    @Test func openingIsOneComposedRequest() async {
        var client = NewsClient.preview
        client.feed = { _, _ in throw Boom() }
        client.narratorNews = { throw Boom() }
        client.opening = { limit in
            NewsOpening(
                feed: CursorPage(FeedEvent.previews, limit: limit, after: nil, cursor: \.id),
                upcoming: UpcomingRelease.previews,
                yearReleases: UpcomingRelease.previews,
                narratorNews: [.preview],
                awards: AwardSection.previews,
                discoveries: MonthlyDiscoveries.preview.suggestions
            )
        }
        let viewModel = NewsViewModel(client: client, caching: false)

        await viewModel.load()

        #expect(viewModel.events.count == FeedEvent.previews.count)
        #expect(viewModel.narratorNews.count == 1)
        #expect(viewModel.errorMessage == nil)
    }

    /// A field in error in the composed request: each section is asked alone,
    /// and only the one that fails keeps what it showed.
    @Test func composedFieldInErrorAsksEachSectionAlone() async {
        var client = NewsClient.preview
        client.opening = { _ in throw APIError.graphQL(messages: ["narratorNews failed"]) }
        client.narratorNews = { throw Boom() }
        let viewModel = NewsViewModel(client: client, caching: false)

        await viewModel.load()

        #expect(viewModel.narratorNews.isEmpty)
        #expect(viewModel.events.count == FeedEvent.previews.count)
        #expect(viewModel.releases.count == UpcomingRelease.previews.count)
    }

    @Test func takingABookGreysItOutAtOnce() async {
        let viewModel = NewsViewModel(client: .preview, caching: false)
        await viewModel.load()
        let event = viewModel.shownEvents.first { !$0.inLibrary }
        #expect(event != nil)

        await viewModel.add(event!, .toRead, as: .book)

        #expect(viewModel.shownEvents.first { $0.id == event!.id }?.inLibrary == true)
    }

    @Test func aFailedAwaitTakesTheMarkBack() async {
        var client = NewsClient.preview
        client.awaitFriendBook = { _, _, _ in throw Boom() }
        let viewModel = NewsViewModel(client: client, caching: false)
        await viewModel.load()
        let event = viewModel.shownEvents[0]

        await viewModel.awaitEdition(event, .audiobook)

        #expect(!viewModel.awaited.contains(event.bookId))
    }

    @Test func wishingAReleaseMarksItsRow() async {
        let viewModel = NewsViewModel(client: .preview, caching: false)
        let item = ReleasedItem.narrator(.preview, day: .now)

        await viewModel.wish(item)

        #expect(viewModel.wished.contains(item.id))
    }

    @Test func aSecondTapTakesTheWishBack() async {
        let removed = Calls()
        var client = NewsClient.preview
        client.wishReleased = { _ in "wish-1" }
        client.removeWish = { removed.record($0) }
        let viewModel = NewsViewModel(client: client, caching: false)
        let card = NewsCard.upcoming(UpcomingRelease.authorPreview)

        await viewModel.wish(card)
        #expect(viewModel.wished.contains(card.key))

        await viewModel.unwish(card)
        #expect(!viewModel.wished.contains(card.key))
        #expect(removed.all == ["wish-1"])
    }

    @Test func aRefusedWishTurnsTheButtonBack() async {
        var client = NewsClient.preview
        client.wishReleased = { _ in throw Boom() }
        let viewModel = NewsViewModel(client: client, caching: false)
        let card = NewsCard.upcoming(UpcomingRelease.authorPreview)

        await viewModel.wish(card)

        #expect(!viewModel.wished.contains(card.key))
    }

    @Test func anAwaitedEditionLeavesTheWishListOnASecondTap() async {
        let stopped = Calls()
        var client = NewsClient.preview
        client.stopAwaiting = { stopped.record($0) }
        let viewModel = NewsViewModel(client: client, caching: false)
        let release = UpcomingRelease.releasedPreviews[1]
        let item = NewsShelfItem(card: .upcoming(release), caption: "")
        #expect(viewModel.wished.isWished(item))

        await viewModel.unwish(item.card)

        #expect(!viewModel.wished.isWished(item))
        #expect(stopped.all == ["projet-derniere-chance"])
    }

    @Test func aCardsAddSaysWhatItDidAndASecondTapTakesItBack() async {
        let deleted = Calls()
        var client = NewsClient.preview
        client.addReleased = { _ in "book-1" }
        client.deleteBook = { deleted.record($0) }
        let viewModel = NewsViewModel(client: client, caching: false)
        let card = NewsCard.suggestion(.preview)

        await viewModel.add(card, .toRead, as: .audiobook)
        #expect(viewModel.wished.state(of: card, isWished: false) == .toRead(isAudio: true))

        await viewModel.undo(card, isWished: false)
        #expect(viewModel.wished.state(of: card, isWished: false) == nil)
        #expect(deleted.all == ["book-1"])
    }

    @Test func aCardTurnedDownStaysGreyUntilThePageComesBack() async {
        let viewModel = NewsViewModel(client: .preview, caching: false)
        let card = NewsCard.suggestion(.preview)

        await viewModel.dismiss(card)
        #expect(viewModel.wished.isTurnedDown(card))
        #expect(!viewModel.dismissed.contains(card.key))

        await viewModel.reconsider(card)
        #expect(!viewModel.wished.isTurnedDown(card))

        await viewModel.dismiss(card)
        await viewModel.loadOnAppear()
        #expect(viewModel.dismissed.contains(card.key))
        #expect(!viewModel.wished.isTurnedDown(card))
    }
}
