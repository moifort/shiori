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

    private func release(_ id: String, _ date: String?, source: ReleaseSource = .awaited) -> UpcomingRelease {
        UpcomingRelease(
            id: id, source: source, format: .book, title: id, authors: [], date: date, coverURL: nil,
            seriesName: nil, volume: nil, author: nil, sagaRating: nil, sagaFavorite: false
        )
    }

    private func laid(_ releases: [UpcomingRelease]) -> ReleaseCalendar {
        ReleaseCalendar(releases: releases, now: now, calendar: calendar)
    }

    @Test func theListStartsTodayAndKeepsTheDaysInOrder() {
        let sheet = laid([
            release("late", "2027-01-30"), release("today", "2026-10-31"), release("out", "2026-10-30"),
            release("far", "2027-05-10"), release("noDay", "2027-01"),
        ])

        let sections = sheet.sections

        #expect(sections.map(\.id) == ["2026-10", "2027-01", "2027-05"])
        #expect(sections[0].days.flatMap(\.releases).map(\.id) == ["today"])
        #expect(sections[1].days.map(\.releases).flatMap { $0 }.map(\.id) == ["late", "noDay"])
    }

    /// A volume with no date closes the list after the years; an edition
    /// awaited that nothing announced yet comes after it, apart.
    @Test func everythingClosesWithTheYearsAndWhatIsUndated() {
        let sheet = laid([
            release("far", "2027-05-10"), release("year", "2028"), release("none", nil, source: .saga),
            release("waiting", nil),
        ])

        let sections = sheet.sections

        #expect(sections.map(\.id) == ["2027-05", "beyond", "awaited"])
        #expect(sections[1].days.map(\.id) == ["year-2028", "undated"])
        #expect(sections[2].days.flatMap(\.releases).map(\.id) == ["waiting"])
    }

    @Test func aReleaseAlreadyOutIsNotInTheList() {
        let sheet = laid([release("past", "2026-09-12"), release("old", "2025")])

        #expect(sheet.sections.isEmpty)
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

    /// Saturday 31 October 2026, noon UTC.
    private let now = Date(timeIntervalSince1970: 1_793_448_000)

    private func event(
        _ id: String, _ kind: FeedEventKind = .loved, friend: String = "f", title: String? = nil, hoursAgo: Double
    ) -> FeedEvent {
        FeedEvent(
            id: id, kind: kind, at: now.addingTimeInterval(-hoursAgo * 3600), friendId: friend,
            friendName: friend.capitalized, bookId: "\(friend)-\(id)", title: title ?? id, authors: ["A"],
            format: .book, coverURL: nil, rating: nil, alsoStartedBy: 0, inLibrary: false
        )
    }

    private func release(_ id: String, _ date: String?, format: BookFormat = .book) -> UpcomingRelease {
        UpcomingRelease(
            id: id, source: .saga, format: format, title: id, authors: [], date: date, coverURL: nil,
            seriesName: nil, volume: nil, author: nil, sagaRating: nil, sagaFavorite: false
        )
    }

    private func news(_ id: String, _ date: String) -> NarratorNews {
        NarratorNews(
            id: id, narratorKey: "k", narrator: "N", title: id, authors: [], date: date,
            coverURL: nil, format: .audiobook
        )
    }

    @Test func releasedKeepsTheLastThirtyDaysNewestFirst() {
        let items = NewsFeedLayout.released(
            releases: [
                release("week", "2026-10-24"), release("today", "2026-10-31"), release("old", "2026-09-30"),
                release("month", "2026-10"), release("year", "2026"), release("coming", "2026-11-04"),
            ],
            narrator: [news("voice", "2026-10-28"), news("oldVoice", "2026-08-01")],
            format: nil,
            now: now,
            calendar: calendar
        )

        #expect(items.map(\.id) == ["release-today", "narrator-voice", "release-week", "release-month"])
    }

    @Test func releasedFallsUnderTheJournalsPeriods() {
        let items = NewsFeedLayout.released(
            releases: [release("week", "2026-10-24"), release("today", "2026-10-31"), release("month", "2026-10")],
            narrator: [news("voice", "2026-10-28")],
            format: nil,
            now: now,
            calendar: calendar
        )

        let sections = NewsFeedLayout.releasedSections(items, now: now, calendar: calendar)

        #expect(sections.map { $0.items.map(\.id) } == [
            ["release-today"], ["narrator-voice"], ["release-week"], ["release-month"],
        ])
    }

    @Test func aRecordingIsAddedHeardAndADraftKeepsItsCover() {
        let item = ReleasedItem.narrator(news("voice", "2026-10-28"), day: now)

        #expect(item.format == .audiobook)
        #expect(item.draft.format == .audiobook)
        #expect(item.draft.media.isEmpty)
        #expect(item.draft.title == "voice")
    }

    @Test func aFormatPillNarrowsReleasedAndKeepsRecordingsForAudio() {
        let releases = [release("book", "2026-10-30"), release("audio", "2026-10-29", format: .audiobook)]
        let voices = [news("voice", "2026-10-28")]

        let books = NewsFeedLayout.released(releases: releases, narrator: voices, format: .book, now: now, calendar: calendar)
        let audio = NewsFeedLayout.released(releases: releases, narrator: voices, format: .audiobook, now: now, calendar: calendar)

        #expect(books.map(\.id) == ["release-book"])
        #expect(audio.map(\.id) == ["release-audio", "narrator-voice"])
    }

    @Test func friendsMovesFallUnderTheirPeriodsTheSameMoveOnOneLine() {
        let sections = NewsFeedLayout.friendSections(
            events: [
                event("vagabond", .started, friend: "sophie", hoursAgo: 2),
                event("dune", friend: "lea", hoursAgo: 3),
                event("vagabond", .started, friend: "marc", hoursAgo: 4),
                event("vagabond", .started, friend: "hugo", hoursAgo: 24 * 40),
            ],
            now: now,
            calendar: calendar
        )

        #expect(sections.count == 2)
        #expect(sections[0].title == String(localized: "Aujourd'hui"))
        #expect(sections[0].moves.map(\.lead.friendId) == ["sophie", "lea"])
        #expect(sections[0].moves[0].others.map(\.friendId) == ["marc"])
        #expect(sections[1].moves.map(\.lead.friendId) == ["hugo"])
    }

    @Test func pickingAFriendKeepsTheirMovesAlone() {
        let sections = NewsFeedLayout.friendSections(
            events: [event("a", friend: "sophie", hoursAgo: 1), event("b", friend: "marc", hoursAgo: 2)],
            friendId: "marc",
            now: now,
            calendar: calendar
        )

        #expect(sections.flatMap(\.moves).map(\.lead.friendId) == ["marc"])
    }

    @Test func theFeedMixesReleasesAndFriendsMovesByDateOverThirtyDays() {
        let released = NewsFeedLayout.released(
            releases: [release("today", "2026-10-31"), release("week", "2026-10-27")],
            narrator: [],
            format: nil,
            now: now,
            calendar: calendar
        )

        let sections = NewsFeedLayout.feedSections(
            released: released,
            events: [
                event("loved", hoursAgo: 2),
                event("started", .started, hoursAgo: 24 * 3),
                event("old", hoursAgo: 24 * 40),
            ],
            format: nil,
            friendId: nil,
            now: now,
            calendar: calendar
        )

        #expect(sections.map { $0.items.map(\.id) } == [
            ["friend-loved", "release-today"], ["friend-started", "release-week"],
        ])
    }

    @Test func aFriendPickedLeavesTheirMovesAloneAndAPillNarrowsThem() {
        let released = NewsFeedLayout.released(
            releases: [release("today", "2026-10-31")], narrator: [], format: nil, now: now, calendar: calendar
        )
        let events = [event("a", friend: "sophie", hoursAgo: 1), event("b", friend: "marc", hoursAgo: 2)]

        let picked = NewsFeedLayout.feedSections(
            released: released, events: events, format: nil, friendId: "marc", now: now, calendar: calendar
        )
        let manga = NewsFeedLayout.feedSections(
            released: [], events: events, format: .manga, friendId: nil, now: now, calendar: calendar
        )

        #expect(picked.flatMap(\.items).map(\.id) == ["friend-b"])
        #expect(manga.isEmpty)
    }

    @Test func aVolumeKnownByItsNumberShowsItsSeriesAboveAndAsItsTitle() {
        let volume = UpcomingRelease(
            id: "berserk", source: .saga, format: .manga, title: "Berserk, tome 43", authors: [], date: "2026-10-28",
            coverURL: nil, seriesName: "Berserk", volume: 43, author: nil, sagaRating: nil, sagaFavorite: true
        )
        let named = UpcomingRelease(
            id: "light", source: .saga, format: .book, title: "Light Bringer", authors: [], date: "2026-10-28",
            coverURL: nil, seriesName: "Red Rising", volume: 6, author: nil, sagaRating: nil, sagaFavorite: false
        )

        #expect(ReleasedItem.release(volume, day: now).shownTitle == "Berserk")
        #expect(ReleasedItem.release(volume, day: now).seriesLine == String(localized: "Berserk · Tome 43"))
        #expect(ReleasedItem.release(named, day: now).shownTitle == "Light Bringer")
    }

    @Test func aStoryIsLitWhenItsFriendMovedSinceTheLastLook() {
        let stories = NewsFeedLayout.stories(
            events: [
                event("a", friend: "sophie", hoursAgo: 1),
                event("b", friend: "lea", hoursAgo: 30),
                event("c", friend: "sophie", hoursAgo: 50),
            ],
            seenAt: now.addingTimeInterval(-24 * 3600)
        )

        #expect(stories.map(\.id) == ["sophie", "lea"])
        #expect(stories.map(\.isNew) == [true, false])
    }
}
