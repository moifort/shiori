import Foundation
import Testing
@testable import Shiori

struct NewsAgendaTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        calendar.locale = Locale(identifier: "fr_FR")
        return calendar
    }

    /// Tuesday 10 November 2026, noon UTC.
    private let now = Date(timeIntervalSince1970: 1_794_312_000)

    private func day(_ iso: String) -> Date {
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))!
    }

    private func release(_ id: String, _ date: String?) -> UpcomingRelease {
        UpcomingRelease(
            id: id, source: .saga, format: .book, title: id, authors: [], date: date, coverURL: nil,
            seriesName: nil, volume: nil, author: nil, sagaRating: nil, sagaFavorite: false
        )
    }

    private func event(_ id: String, at: Date) -> FeedEvent {
        FeedEvent(
            id: id, kind: .loved, at: at, friendId: "marc-\(id)", friendName: "Marc", bookId: id, title: id,
            authors: [], format: .book, coverURL: nil, rating: 5, alsoStartedBy: 0, inLibrary: false
        )
    }

    private func agenda(
        released: [UpcomingRelease] = [],
        events: [FeedEvent] = [],
        upcoming: [UpcomingRelease] = []
    ) -> NewsAgenda {
        NewsAgenda(
            released: NewsFeedLayout.released(releases: released, narrator: [], format: nil, now: now, calendar: calendar),
            events: events,
            upcoming: upcoming,
            suggestions: [],
            awards: [],
            now: now,
            calendar: calendar
        )
    }

    @Test func theWeekRunsMondayToSundayAndOpensOnToday() {
        let agenda = agenda(released: [release("today", "2026-11-10")])

        let week = agenda.weeks[agenda.currentWeek]
        #expect(week.map(\.day) == (9...15).map { day("2026-11-\($0)") })
        #expect(agenda.today == day("2026-11-10"))
        #expect(week[1].cards.map(\.id) == ["release-today"])
    }

    @Test func eachDayHoldsItsOwnNewsNewestFirst() {
        let agenda = agenda(
            released: [release("monday", "2026-11-09")],
            events: [
                event("early", at: day("2026-11-09").addingTimeInterval(3600)),
                event("late", at: day("2026-11-09").addingTimeInterval(20 * 3600)),
            ]
        )

        let monday = agenda.weeks[agenda.currentWeek][0]
        #expect(monday.cards.map(\.id) == ["friend-late", "friend-early", "release-monday"])
    }

    @Test func theWeeksGoBackToTheOldestNews() {
        let agenda = agenda(released: [release("old", "2026-10-28")])

        #expect(agenda.weeks.count == 3)
        #expect(agenda.currentWeek == 2)
        #expect(agenda.weeks[0].first?.day == day("2026-10-26"))
    }

    @Test func daysToComeHoldWhatIsAnnouncedForThem() {
        let agenda = agenda(upcoming: [
            release("thursday", "2026-11-12"), release("nextWeek", "2026-11-18"),
            release("month", "2026-12"), release("past", "2026-11-08"),
        ])

        #expect(agenda.coming.map(\.day) == [day("2026-11-12"), day("2026-11-18")])
        #expect(agenda.weeks[agenda.currentWeek][3].cards.map(\.id) == ["upcoming-thursday"])
        #expect(agenda.weeks.count == 2)
    }

    @Test func nothingAtAllIsEmpty() {
        #expect(agenda().isEmpty)
        #expect(!agenda().hasFriends)
    }
}
