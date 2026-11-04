import Foundation

/// Fixtures draw the typographic stand-in: a preview needs no network.
private func openLibraryCover(_ isbn: String) -> URL? { nil }

extension FeedEvent {
    static let previews: [FeedEvent] = [
        FeedEvent(
            id: "marc~loved~arabe", kind: .loved, at: .now.addingTimeInterval(-3 * 3600),
            friendId: "marc", friendName: "Marc", avatarHero: .gandalf, bookId: "arabe", title: "L'Arabe du futur",
            authors: ["Riad Sattouf"], format: .bandeDessinee, coverURL: openLibraryCover("9782370730008"),
            rating: 5, alsoStartedBy: 0, inLibrary: true
        ),
        FeedEvent(
            id: "sophie~started~vagabond", kind: .started, at: .now.addingTimeInterval(-5 * 3600),
            friendId: "sophie", friendName: "Sophie", avatarHero: .katniss, bookId: "vagabond", title: "Vagabond",
            authors: ["Takehiko Inoue"], format: .manga, coverURL: openLibraryCover("9782845386143"),
            rating: nil, alsoStartedBy: 3, inLibrary: false
        ),
        FeedEvent(
            id: "lea~finished~dune", kind: .finished, at: .now.addingTimeInterval(-3 * 86400),
            friendId: "lea", friendName: "Léa", avatarHero: .hermione, bookId: "dune", title: "Dune",
            authors: ["Frank Herbert"], format: .book, language: .en, coverURL: openLibraryCover("9780441013593"),
            rating: 4, alsoStartedBy: 0, inLibrary: false
        ),
    ]

    /// Marc and Hugo starting Vagabond after Sophie: one line in Amis.
    static let sameStartPreviews: [FeedEvent] = [
        FeedEvent(
            id: "marc~started~vagabond", kind: .started, at: .now.addingTimeInterval(-6 * 3600),
            friendId: "marc", friendName: "Marc", avatarHero: .gandalf, bookId: "vagabond-marc", title: "Vagabond",
            authors: ["Takehiko Inoue"], format: .manga, coverURL: nil,
            rating: nil, alsoStartedBy: 3, inLibrary: false
        ),
        FeedEvent(
            id: "hugo~started~vagabond", kind: .started, at: .now.addingTimeInterval(-7 * 3600),
            friendId: "hugo", friendName: "Hugo", bookId: "vagabond-hugo", title: "Vagabond",
            authors: ["Takehiko Inoue"], format: .manga, coverURL: nil,
            rating: nil, alsoStartedBy: 3, inLibrary: false
        ),
    ]
}

extension NarratorNews {
    static let preview = NarratorNews(
        id: "gabay~fondation", narratorKey: "bernard-gabay", narrator: "Bernard Gabay", title: "Fondation",
        authors: ["Isaac Asimov"], date: Date.now.formatted(.iso8601.year().month().day()),
        coverURL: openLibraryCover("9782072911538"), format: .audiobook
    )
}

extension UpcomingRelease {
    private static let pierce = AuthorRef(key: "pierce-brown", name: "Pierce Brown", favorite: true, portraitURL: nil)

    /// The favourite author's announcement, the feed's spotlight.
    static let authorPreview = UpcomingRelease(
        id: "saga~red-rising~6", source: .saga, format: .book, title: "Light Bringer",
        authors: ["Pierce Brown"], date: Self.isoDay(daysAhead: 48), coverURL: openLibraryCover("9780593157459"),
        seriesName: "Red Rising", volume: 6, author: pierce, sagaRating: 5, sagaFavorite: true
    )

    /// Out lately among what the reader follows: "Sorti".
    static let releasedPreviews: [UpcomingRelease] = [
        UpcomingRelease(
            id: "saga~berserk~42", source: .saga, format: .manga, title: "Berserk, tome 42",
            authors: ["Kentaro Miura"], date: isoDay(daysAhead: -6), coverURL: openLibraryCover("9782344040003"),
            seriesName: "Berserk", volume: 42, author: nil, sagaRating: nil, sagaFavorite: true
        ),
        UpcomingRelease(
            id: "awaited~projet-derniere-chance", source: .awaited, format: .audiobook, title: "Projet Dernière Chance",
            authors: ["Andy Weir"], date: isoDay(daysAhead: -12), coverURL: nil,
            seriesName: nil, volume: nil, author: nil, sagaRating: nil, sagaFavorite: false
        ),
        UpcomingRelease(
            id: "saga~expanse~9", source: .saga, format: .book, title: "The Expanse, tome 9",
            authors: ["James S. A. Corey"], date: isoDay(daysAhead: -45), coverURL: openLibraryCover("9780316332941"),
            seriesName: "The Expanse", volume: 9, author: nil, sagaRating: 4, sagaFavorite: false,
            language: .en
        ),
    ]

    static let previews: [UpcomingRelease] = [
        authorPreview,
        UpcomingRelease(
            id: "author~piranesi", source: .author, format: .book, title: "Piranesi",
            authors: ["Susanna Clarke"], date: isoThisMonth(day: 4), coverURL: openLibraryCover("9781635575637"),
            seriesName: nil, volume: nil,
            author: .init(key: "susanna-clarke", name: "Susanna Clarke", favorite: true, portraitURL: nil),
            sagaRating: nil, sagaFavorite: false
        ),
        UpcomingRelease(
            id: "saga~berserk~43", source: .saga, format: .manga, title: "Berserk, tome 43",
            authors: ["Kentaro Miura"], date: isoThisMonth(day: 4), coverURL: openLibraryCover("9782344040003"),
            seriesName: "Berserk", volume: 43, author: nil, sagaRating: nil, sagaFavorite: true
        ),
        UpcomingRelease(
            id: "awaited~seul-sur-mars", source: .awaited, format: .audiobook, title: "Seul sur Mars",
            authors: ["Andy Weir"], date: isoThisMonth(day: 20), coverURL: openLibraryCover("9782266250115"),
            seriesName: nil, volume: nil, author: nil, sagaRating: nil, sagaFavorite: false
        ),
        UpcomingRelease(
            id: "saga~expanse~10", source: .saga, format: .book, title: "The Expanse, tome 10",
            authors: ["James S. A. Corey"], date: isoMonth(monthsAhead: 8), coverURL: openLibraryCover("9780316332941"),
            seriesName: "The Expanse", volume: 10, author: nil, sagaRating: 4, sagaFavorite: false
        ),
        UpcomingRelease(
            id: "saga~frieren~16", source: .saga, format: .manga, title: "Frieren, tome 16",
            authors: ["Kanehito Yamada"], date: isoYear(yearsAhead: 2), coverURL: nil,
            seriesName: "Frieren", volume: 16, author: nil, sagaRating: nil, sagaFavorite: true
        ),
        UpcomingRelease(
            id: "awaited~portes-de-pierre", source: .awaited, format: .book, title: "Les Portes de pierre",
            authors: ["Patrick Rothfuss"], date: nil, coverURL: nil,
            seriesName: nil, volume: nil, author: nil, sagaRating: nil, sagaFavorite: false
        ),
        UpcomingRelease(
            id: "author~weir-sans-titre", source: .author, format: .book, title: nil,
            authors: ["Andy Weir"], date: nil, coverURL: nil, seriesName: nil, volume: nil,
            author: .init(key: "andy-weir", name: "Andy Weir", favorite: false, portraitURL: nil),
            sagaRating: nil, sagaFavorite: false
        ),
    ]

    private static func isoDay(daysAhead: Int) -> String {
        Date.now.addingTimeInterval(Double(daysAhead) * 86400).formatted(.iso8601.year().month().day())
    }

    /// A day of the month the preview runs in, so the grid always has dots.
    private static func isoThisMonth(day: Int) -> String {
        let month = String(Date.now.formatted(.iso8601.year().month().day()).prefix(7))
        return String(format: "%@-%02d", month, day)
    }

    private static func isoMonth(monthsAhead: Int) -> String {
        let date = Calendar.current.date(byAdding: .month, value: monthsAhead, to: .now) ?? .now
        return String(date.formatted(.iso8601.year().month().day()).prefix(7))
    }

    private static func isoYear(yearsAhead: Int) -> String {
        String((Calendar.current.component(.year, from: .now)) + yearsAhead)
    }
}
