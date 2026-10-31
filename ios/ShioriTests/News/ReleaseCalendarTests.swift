import Foundation
import Testing
@testable import Shiori

struct ReleaseCalendarTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        calendar.locale = Locale(identifier: "fr_FR")
        return calendar
    }

    /// Saturday 31 October 2026.
    private let now = Date(timeIntervalSince1970: 1_793_448_000)

    private func release(_ id: String, _ date: String?) -> UpcomingRelease {
        UpcomingRelease(
            id: id, source: .awaited, format: .book, title: id, authors: [], date: date, coverURL: nil,
            seriesName: nil, volume: nil, author: nil, sagaRating: nil, sagaFavorite: false
        )
    }

    private func laid(_ releases: [UpcomingRelease]) -> ReleaseCalendar {
        ReleaseCalendar(releases: releases, now: now, calendar: calendar)
    }

    @Test func aDayLandsOnItsCellAndAMonthWithoutADayStaysApart() {
        let month = laid([release("a", "2026-10-31"), release("b", "2026-10"), release("c", "2026-11-04")]).thisMonth

        #expect(month.byDay[31]?.map(\.id) == ["a"])
        #expect(month.monthOnly.map(\.id) == ["b"])
        #expect(month.dayCount == 31)
        // 1 October 2026 is a Thursday: three blank cells, the week starting on Monday.
        #expect(month.leadingBlanks == 3)
    }

    @Test func sixMonthsStartThisMonthAndTheSeventhIsLater() {
        let sheet = laid([release("near", "2027-03-02"), release("far", "2027-05-10"), release("year", "2028")])

        #expect(sheet.sixMonths.count == 6)
        #expect(sheet.sixMonths.last?.all.map(\.id) == ["near"])
        #expect(sheet.later.map(\.year) == [2027, 2028])
        #expect(sheet.later.first?.rows.map(\.release.id) == ["far"])
        #expect(sheet.later.first?.rows.first?.month != nil)
    }

    @Test func aReleaseAlreadyOutIsNotOnTheCalendar() {
        let sheet = laid([release("past", "2026-09-12"), release("old", "2025")])

        #expect(sheet.thisMonth.all.isEmpty)
        #expect(sheet.later.isEmpty)
        #expect(sheet.undated.isEmpty)
    }

    @Test func undatedReleasesHaveTheirOwnGroup() {
        let sheet = laid([release("a", nil), release("b", "2026-11-04")])

        #expect(sheet.undated.map(\.id) == ["a"])
    }

    @Test func theCalendarOpensOnTodayThenOnTheNextDayThatHasARelease() {
        let sheet = laid([release("a", "2026-10-31"), release("b", "2026-10-10")])
        #expect(sheet.initialDay(in: sheet.thisMonth) == 31)

        let november = laid([release("c", "2026-10-02")])
        #expect(november.initialDay(in: november.thisMonth) == 2)
    }

    @Test func starsAreFiveGlyphs() {
        #expect(UpcomingRelease.stars(4) == "★★★★☆")
        #expect(UpcomingRelease.stars(5) == "★★★★★")
    }
}

struct NewsFeedLayoutTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    private let now = Date(timeIntervalSince1970: 1_793_448_000)

    private func event(_ id: String, hoursAgo: Double) -> FeedEvent {
        var event = FeedEvent.previews[0]
        event = FeedEvent(
            id: id, kind: .loved, at: now.addingTimeInterval(-hoursAgo * 3600), friendId: "f",
            friendName: "F", bookId: id, title: id, authors: [], format: .book, coverURL: nil,
            rating: nil, alsoStartedBy: 0, inLibrary: false
        )
        return event
    }

    @Test func eventsGroupByHowLongAgoAndCardsSlotIn() {
        let sections = NewsFeedLayout.sections(
            events: [event("a", hoursAgo: 1), event("b", hoursAgo: 2), event("c", hoursAgo: 3), event("d", hoursAgo: 30), event("e", hoursAgo: 24 * 4)],
            spotlight: .authorPreview,
            award: .newsPreview,
            now: now,
            calendar: calendar
        )

        #expect(sections.map(\.title) == ["Aujourd'hui", "Hier", "Cette semaine"])
        #expect(sections[0].items.map(\.id) == ["friend-a", "friend-b", "author-saga~red-rising~6", "friend-c"])
        #expect(sections[1].items.first?.id == "award-klara--kazuo-ishiguro")
    }

    @Test func aFeedWithNoEventStillShowsItsCards() {
        let sections = NewsFeedLayout.sections(events: [], spotlight: .authorPreview, award: nil, now: now, calendar: calendar)

        #expect(sections.flatMap(\.items).map(\.id) == ["author-saga~red-rising~6"])
    }
}
