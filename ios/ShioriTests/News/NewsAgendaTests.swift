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

    @Test func theHeadlinesAreTheNearestReleasesEitherSideOfTodayAndTheFriendsLatestOpeningOnTheNextOne() {
        let agenda = agenda(
            released: (1...6).map { release("out\($0)", String(format: "2026-11-%02d", $0)) },
            events: [event("friend", at: day("2026-11-09"))],
            upcoming: [
                release("soon", "2026-11-12"), release("month", "2026-12"), release("far", "2027-01-20"),
            ]
        )

        #expect(agenda.highlights.map(\.id) == [
            "release-out3", "release-out4", "release-out5", "release-out6", "friend-friend", "upcoming-soon",
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

    @Test func onlyTwoOfTheFriendsLatestFavouritesOrFinishedBooksMakeTheHeadlines() {
        var started = event("started", at: day("2026-11-10"))
        started = FeedEvent(
            id: started.id, kind: .started, at: started.at, friendId: "lea", friendName: "Léa", bookId: "started",
            title: "started", authors: [], format: .book, coverURL: nil, rating: nil, alsoStartedBy: 0, inLibrary: false
        )
        let agenda = agenda(events: [
            started,
            event("new", at: day("2026-11-09")), event("mid", at: day("2026-11-08")), event("old", at: day("2026-11-07")),
        ])

        #expect(agenda.highlights.map(\.id) == ["friend-mid", "friend-new"])
    }

    private func followed(
        _ id: String, _ source: ReleaseSource, _ date: String?, series: String? = nil, volume: Int? = nil,
        favorite: Bool = true, narrator: String? = nil
    ) -> UpcomingRelease {
        UpcomingRelease(
            id: id, source: source, format: .book, title: id, authors: ["Martha Wells"], date: date, coverURL: nil,
            seriesName: series, volume: volume,
            author: .init(key: "wells", name: "Martha Wells", favorite: favorite, portraitURL: nil),
            sagaRating: nil, sagaFavorite: false, narrator: narrator
        )
    }

    @Test func theShelvesSortEachFollowOutFirstThenToCome() {
        let out = [
            followed("witcherOut", .saga, "2026-11-02", series: "Le Sorceleur", volume: 8),
            followed("authorOut", .author, "2026-10-28"),
            followed("shyAuthor", .author, "2026-11-01", favorite: false),
            followed("wishOut", .awaited, "2026-11-05"),
        ]
        let ahead = [
            followed("witcherNext", .saga, "2026-11-14", series: "Le Sorceleur", volume: 9),
            followed("frierenNext", .saga, "2026-12", series: "Frieren", volume: 15),
            followed("authorNext", .author, "2027-03"),
            followed("voice", .narrator, "2026-11-20", narrator: "Bernard Gabay"),
            followed("wishNext", .awaited, nil),
            followed("gone", .awaited, "2026-11-08"),
        ]
        let agenda = agenda(released: out, upcoming: ahead)
        let shelves = NewsAgenda(
            released: NewsFeedLayout.released(releases: out, narrator: [], format: nil, now: now, calendar: calendar),
            events: [], upcoming: [], announced: ahead, suggestions: [], awards: [], now: now, calendar: calendar
        ).shelves

        #expect(agenda.shelves.series.isEmpty == false)
        #expect(shelves.series.map(\.id) == ["release-witcherOut", "upcoming-frierenNext"])
        #expect(shelves.series.first?.caption == String(localized: "Tome \(8) · \(String(localized: "sorti"))"))
        #expect(shelves.authors.map(\.id) == ["release-authorOut", "upcoming-authorNext"])
        #expect(shelves.authors.first?.person == "Martha Wells")
        #expect(shelves.narrators.map(\.id) == ["upcoming-voice"])
        #expect(shelves.narrators.first?.person == "Bernard Gabay")
        #expect(shelves.wishes.map(\.id) == ["release-wishOut", "upcoming-wishNext"])
        #expect(shelves.wishes.last?.caption == String(localized: "En vue"))
    }

    @Test func theFriendsShelfHoldsTheirRecentFavouritesOnly() {
        var finished = event("finished", at: day("2026-11-09"))
        finished = FeedEvent(
            id: finished.id, kind: .finished, at: finished.at, friendId: "sophie", friendName: "Sophie",
            bookId: "finished", title: "finished", authors: [], format: .book, coverURL: nil, rating: 4,
            alsoStartedBy: 0, inLibrary: false
        )
        let agenda = agenda(events: [event("loved", at: day("2026-11-08")), finished])

        #expect(agenda.shelves.loves.map(\.lead.id) == ["loved"])
    }

    @Test func aPersonsNameShortensToItsInitialAndLastName() {
        #expect(NewsPersonTile.shortName("Martha Wells") == "M. Wells")
        #expect(NewsPersonTile.shortName("Adrian Tchaikovsky") == "A. Tchaikovsky")
        #expect(NewsPersonTile.shortName("Moebius") == "Moebius")
    }

    @Test func nothingAtAllIsEmpty() {
        #expect(agenda().isEmpty)
        #expect(!agenda().hasFriends)
    }
}
