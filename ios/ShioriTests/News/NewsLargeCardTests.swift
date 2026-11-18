import Foundation
import Testing
@testable import Shiori

struct NewsLargeCardTests {
    private func release(_ id: String) -> UpcomingRelease {
        UpcomingRelease.previews.first { $0.id == id }!
    }

    private func item(_ card: NewsCard) -> NewsShelfItem {
        NewsShelfItem(card: card, caption: "")
    }

    @Test func aVolumeToComeNamesItsNumberAndKeepsItsDay() {
        let berserk = release("saga~berserk~43")
        let card = item(.upcoming(berserk))

        #expect(card.word == String(localized: "Tome \(43)"))
        #expect(card.day == berserk.date)
    }

    @Test func anAwaitedEditionIsInTheWishListAlready() {
        let dated = item(.upcoming(release("awaited~seul-sur-mars")))
        let undated = item(.upcoming(release("awaited~portes-de-pierre")))

        #expect(dated.word == String(localized: "À paraître"))
        #expect(dated.isAwaited)
        #expect(undated.word == String(localized: "En vue"))
        #expect(undated.day == nil)
    }

    @Test func anAuthorsBookIsAnnounced() {
        let card = item(.upcoming(release("author~piranesi")))

        #expect(card.word == String(localized: "Annoncé"))
        #expect(!card.isAwaited)
    }

    @Test func aBookOutSaysSoAndItsDayAsTheLeafReadsIt() {
        let calendar = Calendar(identifier: .gregorian)
        let day = calendar.date(from: DateComponents(year: 2026, month: 10, day: 3))!
        let card = item(.released(.release(release("author~piranesi"), day: day)))

        #expect(card.word == String(localized: "Sorti"))
        #expect(NewsShelfItem.isoDay(day, calendar: calendar) == "2026-10-03")
    }

    @Test func aFriendsMoveSaysWhatTheyDidAndOnWhichDay() {
        let move = NewsFeedLayout.friendSections(events: FeedEvent.previews).flatMap(\.moves)
            .first { $0.lead.kind == .loved }!
        let card = item(.friend(move))

        #expect(card.word == NewsShelves.action(move.lead))
        #expect(card.day == NewsShelfItem.isoDay(move.lead.at))
    }

    @Test func aPrizeHasNoDay() {
        #expect(item(.award(.preview)).day == nil)
    }
}
