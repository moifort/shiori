import Foundation
import Testing
@testable import Shiori

struct NewsPillFormatsTests {
    private func feed(_ events: [FeedEvent]) -> [NewsFeedSection] {
        NewsFeedLayout.feedSections(released: [], events: events, format: nil, friendId: nil)
    }

    @Test func pillsOfferOnlyTheFormatsTheFeedHolds() {
        let events = FeedEvent.previews.filter { $0.at >= .now.addingTimeInterval(-29 * 86400) }
        let present = Set(events.map(\.format))

        let pills = NewsFeedLayout.pillFormats(in: feed(events), selected: nil)

        #expect(pills == NewsFeedLayout.pillFormats.filter(present.contains))
        #expect(!pills.contains(.comic))
    }

    @Test func thePickedPillStaysEvenWhenNothingIsInIt() {
        let pills = NewsFeedLayout.pillFormats(in: feed([]), selected: .comic)

        #expect(pills == [.comic])
    }

    @Test func anEmptyFeedOffersNoPill() {
        #expect(NewsFeedLayout.pillFormats(in: feed([]), selected: nil).isEmpty)
    }
}
