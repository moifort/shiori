import Foundation

// Découvrir's preview and test data: a saga heard with its next volume
// announced, a saga read with two volumes just out, an author with a work
// announced, an edition awaited, an award winner and a friend's heart.

extension SagaDiscovery {
    /// Dungeon Crawler Carl heard, its eighth volume announced.
    static let preview = SagaDiscovery(
        series: FollowedSeries(
            seriesId: "dcc",
            name: "Dungeon Crawler Carl",
            isAudio: true,
            author: "Matt Dinniman",
            language: .fr,
            state: .inProgress,
            genre: .fantasy,
            ownedCount: 7
        ),
        releases: SagaReleases(
            watched: true,
            next: DiscoveredVolume(
                number: 8,
                title: "Le Livre du Carnage",
                date: "2026-11-05",
                isbn13: nil,
                coverURL: nil
            )
        )
    )

    /// The Expanse read, two volumes just out the reader has not added.
    static let previewRead = SagaDiscovery(
        series: FollowedSeries(
            seriesId: "expanse",
            name: "The Expanse",
            author: "James S. A. Corey",
            language: .fr,
            state: .inProgress,
            genre: .scienceFiction,
            ownedCount: 6
        ),
        releases: SagaReleases(watched: true, next: nil),
        missing: [7, 8],
        recent: [
            DiscoveredVolume(number: 8, title: "La Colère de Tiamat", date: "2026-10-08", isbn13: nil, coverURL: nil),
            DiscoveredVolume(number: 7, title: "Les Jeux de Persépolis", date: "2026-10-01", isbn13: nil, coverURL: nil),
        ]
    )
}

extension DiscoveryVolume {
    /// The next volume of Dungeon Crawler Carl, announced.
    static let preview = DiscoveryVolume(saga: .preview, volume: SagaDiscovery.preview.releases.next!)
}

extension AuthorDiscovery {
    /// Matt Dinniman on the Authors shelf heard: a work of his own announced,
    /// an edition followed, and the next volume of his saga the Books shelf
    /// lists, just out and announced.
    static let preview: AuthorDiscovery = {
        var saga = SagaDiscovery.preview
        saga.recent = [DiscoveredVolume(
            number: 7,
            title: "La Parade de Mondes",
            date: "2026-09-24",
            isbn13: nil,
            coverURL: nil
        )]
        return AuthorDiscovery(
            author: FollowedAuthor(
                key: "matt-dinniman",
                name: "Matt Dinniman",
                indexLetter: "D",
                portraitURL: nil,
                bookCount: 7,
                seriesCount: 1,
                favoriteCount: 1,
                averageRating: 4.5,
                shelvedAt: nil,
                books: []
            ),
            next: DiscoveredWork(
                title: "Kaiju Battlefield Surgeon",
                date: "2027-02-16",
                isbn13: nil,
                coverURL: nil,
                seriesName: nil,
                volume: nil
            ),
            recent: [],
            awaited: [.preview],
            sagas: [saga]
        )
    }()
}

extension AwaitedEdition {
    /// A recording of the next Dungeon Crawler Carl, announced.
    static let preview = AwaitedEdition(
        id: "preview",
        format: .audiobook,
        state: .announced,
        title: "Opération Bounce House",
        originalTitle: "Operation Bounce House",
        originalLanguage: .en,
        authors: ["Matt Dinniman"],
        date: "2026-11-05",
        coverURL: nil,
        storeURL: URL(string: "https://www.audible.fr/search?keywords=Op%C3%A9ration%20Bounce%20House%20Matt%20Dinniman"),
        awaitedAt: .now.addingTimeInterval(-3 * 86400),
        bookId: "book",
        ownerId: "me"
    )
}

extension AwardWinner {
    /// A winner in English nobody awaited yet: both formats left to await.
    static let preview = AwardWinner(
        id: "the-buffalo-hunter-hunter--stephen-graham-jones",
        format: .book,
        title: "The Buffalo Hunter Hunter",
        originalTitle: "The Buffalo Hunter Hunter",
        originalLanguage: .en,
        authors: ["Stephen Graham Jones"],
        mentions: [AwardMention(award: .nebula, year: 2026)],
        state: .unannounced,
        watched: false,
        date: nil,
        coverURL: nil,
        storeURL: nil,
        awaitableFormats: [.book, .audiobook],
        awaitedEditionId: nil
    )

    /// A Goncourt in a French app: out in print, only its recording to await.
    static let goncourtPreview = AwardWinner(
        id: "la-maison-vide--laurent-mauvignier",
        format: .book,
        title: "La Maison vide",
        originalTitle: "La Maison vide",
        originalLanguage: .fr,
        authors: ["Laurent Mauvignier"],
        mentions: [AwardMention(award: .goncourt, year: 2025)],
        state: .available,
        watched: false,
        date: nil,
        coverURL: nil,
        storeURL: nil,
        awaitableFormats: [.audiobook],
        awaitedEditionId: nil
    )
}

extension AwardSection {
    static let previews = [
        AwardSection(genre: .fantasy, winners: [.preview]),
        AwardSection(genre: .literaryFiction, winners: [.goncourtPreview]),
    ]
}

extension FriendPicks {
    /// A book a friend hearted, a saga two friends love and its author.
    static let preview: FriendPicks = {
        let lea = FriendLovers.Lover(userId: "lea", firstName: "Léa")
        let paul = FriendLovers.Lover(userId: "paul", firstName: "Paul")
        let many = FriendLovers(friends: [paul, lea], lovedByMany: true)
        return FriendPicks(
            books: [LovedBook(book: .preview, lovers: FriendLovers(friends: [lea], lovedByMany: false))],
            sagas: [LovedSaga(
                saga: FriendSaga(
                    id: "kingkiller",
                    seriesId: "kingkiller",
                    name: "Chronique du Tueur de Roi",
                    author: "Patrick Rothfuss",
                    language: .fr,
                    ownedCount: 2,
                    favorite: true,
                    genre: .fantasy,
                    subgenre: nil,
                    volumes: [Book(id: "wind", title: "Le Nom du vent", authors: ["Patrick Rothfuss"], status: .read)]
                ),
                lovers: many
            )],
            authors: [LovedAuthor(key: "patrick-rothfuss", name: "Patrick Rothfuss", portraitURL: nil, lovers: many)]
        )
    }()
}

extension DiscoveryFeed {
    /// Both formats loaded: a saga of each, an author heard, an edition
    /// awaited and a friend's heart.
    static let preview = DiscoveryFeed(
        rows: [.book: [.previewRead], .audiobook: [.preview]],
        authors: [.audiobook: [.preview]],
        followed: [.book: 1, .audiobook: 2],
        picks: .preview,
        awaited: [.audiobook: [.preview]]
    )

    /// The tab in one format, as the server answers it.
    func page(_ format: ReleaseFormat) -> DiscoveryPage {
        DiscoveryPage(
            rows: rows[format] ?? [],
            authors: authors[format] ?? [],
            unwatched: 0,
            followed: followed[format] ?? 0
        )
    }
}

extension ReleaseDescription {
    /// What the model writes of an announced volume.
    static let preview = ReleaseDescription(
        book: ScannedBook(
            recognized: true,
            title: "Le Livre du Carnage",
            authors: ["Matt Dinniman"],
            publisher: "Bragelonne",
            synopsis: "Carl et Princesse Donut descendent au neuvième étage du donjon, où les règles changent encore.",
            genre: .fantasy
        ),
        narrators: ["Jeff Hays"],
        durationMinutes: 1_260
    )
}
