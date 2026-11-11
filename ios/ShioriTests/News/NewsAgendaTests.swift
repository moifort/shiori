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

    @Test func onlyTheDaysWithNewsAreInTheStripAndItOpensOnToday() {
        let agenda = agenda(released: [release("today", "2026-11-10"), release("old", "2026-10-28")])

        #expect(agenda.days.map(\.day) == [day("2026-10-28"), day("2026-11-10")])
        #expect(agenda.today == day("2026-11-10"))
        #expect(agenda.openingDay == day("2026-11-10"))
        #expect(agenda.days.last?.cards.map(\.id) == ["release-today"])
    }

    @Test func eachDayHoldsItsOwnNewsNewestFirst() {
        let agenda = agenda(
            released: [release("monday", "2026-11-09")],
            events: [
                event("early", at: day("2026-11-09").addingTimeInterval(3600)),
                event("late", at: day("2026-11-09").addingTimeInterval(20 * 3600)),
            ]
        )

        #expect(agenda.days.first?.cards.map(\.id) == ["friend-late", "friend-early", "release-monday"])
    }

    @Test func aQuietTodayOpensOnTheNearestDayTheOneToComeOnATie() {
        let agenda = agenda(
            released: [release("before", "2026-11-07")],
            upcoming: [release("after", "2026-11-13")]
        )

        #expect(!agenda.days.contains { $0.day == day("2026-11-10") })
        #expect(agenda.openingDay == day("2026-11-13"))
    }

    @Test func daysToComeHoldWhatIsAnnouncedForThemAMonthAhead() {
        let agenda = agenda(upcoming: [
            release("thursday", "2026-11-12"), release("nextWeek", "2026-11-18"),
            release("month", "2026-12"), release("past", "2026-11-08"), release("far", "2027-01-20"),
        ])

        #expect(agenda.days.map(\.day) == [day("2026-11-12"), day("2026-11-18")])
        #expect(agenda.days.first?.cards.map(\.id) == ["upcoming-thursday"])
    }

    @Test func theTempsFortsAreTheNearestReleasesEitherSideOfTodayOpeningOnTheNextOne() {
        let agenda = agenda(
            released: (1...6).map { release("out\($0)", String(format: "2026-11-%02d", $0)) },
            events: [event("friend", at: day("2026-11-09"))],
            upcoming: [
                release("soon", "2026-11-12"), release("month", "2026-12"), release("far", "2027-01-20"),
            ]
        )

        #expect(agenda.highlights.map(\.id) == [
            "release-out3", "release-out4", "release-out5", "release-out6", "upcoming-soon",
        ])
        #expect(agenda.highlights.last?.day == day("2026-11-12"))
        #expect(agenda.openingHighlight == "upcoming-soon")
    }

    @Test func theYearsPrizesAreOnlyThisYearsWinnersBarTheDismissed() {
        func winner(_ id: String, _ year: Int) -> AwardWinner {
            let base = AwardWinner.preview
            return AwardWinner(
                id: id, format: base.format, title: id, originalTitle: id, originalLanguage: nil, authors: [],
                mentions: [AwardMention(award: .hugo, year: year)], state: base.state, watched: false,
                date: nil, coverURL: nil, storeURL: nil, awaitableFormats: base.awaitableFormats,
                awaitedEditionId: nil, key: id
            )
        }
        let sections = [
            AwardSection(genre: .fantasy, winners: [winner("now", 2026), winner("old", 2025), winner("gone", 2026)]),
        ]
        let agenda = NewsAgenda(
            released: [], events: [], upcoming: [], suggestions: [], awards: sections,
            dismissed: ["award-gone"], now: now, calendar: calendar
        )
        let none = NewsAgenda(
            released: [], events: [], upcoming: [], suggestions: [],
            awards: [AwardSection(genre: .fantasy, winners: [winner("old", 2025)])], now: now, calendar: calendar
        )

        #expect(agenda.prizes.map(\.id) == ["award-now"])
        #expect(none.prizes.isEmpty)
    }

    @Test func nothingAtAllIsEmpty() {
        #expect(agenda().isEmpty)
        #expect(!agenda().hasFriends)
    }
}
