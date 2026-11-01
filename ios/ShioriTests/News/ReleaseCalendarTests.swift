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

    @Test func thirtyDaysRollFromTodayAndKeepTheDaysInOrder() {
        let sheet = laid([
            release("late", "2026-11-30"), release("today", "2026-10-31"), release("out", "2026-10-30"),
            release("far", "2026-12-02"), release("noDay", "2026-11"),
        ])

        let sections = sheet.sections(for: .thirtyDays)

        #expect(sections.map(\.id) == ["2026-10", "2026-11"])
        #expect(sections[0].days.flatMap(\.releases).map(\.id) == ["today"])
        #expect(sections[1].days.map(\.releases).flatMap { $0 }.map(\.id) == ["late", "noDay"])
    }

    @Test func sixMonthsStopWhereTheSeventhBegins() {
        let sheet = laid([release("near", "2027-03-02"), release("far", "2027-05-10"), release("year", "2028")])

        #expect(sheet.sections(for: .sixMonths).flatMap(\.days).flatMap(\.releases).map(\.id) == ["near"])
    }

    @Test func everythingClosesWithTheYearsAndWhatIsUndated() {
        let sheet = laid([release("far", "2027-05-10"), release("year", "2028"), release("none", nil)])

        let sections = sheet.sections(for: .all)

        #expect(sections.map(\.id) == ["2027-05", "beyond"])
        #expect(sections[1].days.map(\.id) == ["year-2028", "undated"])
    }

    @Test func aReleaseAlreadyOutIsNotInTheList() {
        let sheet = laid([release("past", "2026-09-12"), release("old", "2025")])

        #expect(sheet.sections(for: .all).isEmpty)
    }

    @Test func aHorizonWithNothingInItIsEmpty() {
        let sheet = laid([release("far", "2027-05-10")])

        #expect(sheet.sections(for: .thirtyDays).isEmpty)
        #expect(sheet.sections(for: .sixMonths).isEmpty)
        #expect(!sheet.sections(for: .all).isEmpty)
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

        #expect(sections.map(\.title) == ["Cette semaine"])
        #expect(sections[0].items.map(\.id) == [
            "friend-a", "friend-b", "author-saga~red-rising~6", "friend-c",
            "award-klara--kazuo-ishiguro", "friend-d", "friend-e",
        ])
    }

    @Test func aNarratorsRecordingFallsOnTheDayItCameOut() {
        let day = now.addingTimeInterval(-3 * 86_400).formatted(.iso8601.year().month().day())
        let news = NarratorNews(
            id: "n", narratorKey: "k", narrator: "N", title: "T", authors: [], date: day,
            coverURL: nil, format: .audiobook
        )

        let sections = NewsFeedLayout.sections(
            events: [event("a", hoursAgo: 1), event("b", hoursAgo: 24 * 6)],
            narrator: [news],
            spotlight: nil,
            award: nil,
            now: now,
            calendar: calendar
        )

        #expect(sections.map(\.title) == ["Cette semaine"])
        #expect(sections[0].items.map(\.id) == ["friend-a", "narrator-n", "friend-b"])
    }

    @Test func aFeedWithNoEventStillShowsItsCards() {
        let sections = NewsFeedLayout.sections(events: [], spotlight: .authorPreview, award: nil, now: now, calendar: calendar)

        #expect(sections.flatMap(\.items).map(\.id) == ["author-saga~red-rising~6"])
    }
}
