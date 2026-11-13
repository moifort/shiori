#if DEBUG
import Foundation

/// The showcase's friends, scan, store and month's discoveries, drawn from
/// the shelf in Showcase.swift. Debug-only, as the rest of the showcase.
extension Showcase {
    // MARK: - Friends

    private static func friendBook(_ book: Book, favoritedAt: Date? = nil, activity days: Double) -> FriendBook {
        FriendBook(
            book: book,
            inLibrary: Self.book(id: book.id) != nil,
            favoritedAt: favoritedAt,
            lastActivityAt: daysAgo(days)
        )
    }

    /// A book a friend holds that the reader does not.
    static func theirs(
        _ id: String, _ title: String, _ authors: [String], format: BookFormat = .book,
        status: ReadingStatus, series: (name: String, volume: Int)? = nil
    ) -> Book {
        Book(
            id: "friend-\(id)",
            title: title,
            authors: authors,
            format: format,
            language: language,
            series: series.map { SeriesMembership(id: $0.name, name: $0.name, volume: $0.volume, kind: .main) },
            coverURL: cover(id),
            status: status
        )
    }

    private static let sorceleur = theirs(
        "sorceleur-01", local("Le Dernier Vœu", "The Last Wish"), ["Andrzej Sapkowski"], status: .read,
        series: (local("Sorceleur", "The Witcher"), 1)
    )
    private static let spyFamily = theirs(
        "spy-family-01", local("Spy x Family, tome 1", "Spy x Family, Vol. 1"), ["Tatsuya Endo"],
        format: .manga, status: .read, series: ("Spy x Family", 1)
    )

    /// The friends, by the names they go by in each language.
    private static let lea = local("Léa", "Emma")
    private static let hugo = local("Hugo", "Jack")
    private static let camille = local("Camille", "Chloe")

    private static func shared(_ id: String) -> Book {
        guard let book = book(id: id) else { fatalError("no showcase book \(id)") }
        return book
    }

    static let friends: [Friend] = [
        Friend(
            userId: "lea", firstName: lea, since: daysAgo(400), bookCount: 186, favoriteCount: 23,
            readingCount: 2, toReadCount: 31, readThisYear: 41,
            recentActivity: [
                .hearted(friendBook(sorceleur, favoritedAt: daysAgo(1), activity: 1), at: daysAgo(1)),
                .finished(friendBook(shared("horde-du-contrevent"), activity: 3), at: daysAgo(3)),
                .reading(friendBook(shared("furtifs"), activity: 2), at: daysAgo(2)),
                .added(friendBook(shared("demain-et-demain"), activity: 6), at: daysAgo(6)),
            ]
        ),
        Friend(
            userId: "hugo", firstName: hugo, since: daysAgo(250), bookCount: 142,
            favoriteCount: 12, readingCount: 1, toReadCount: 9, readThisYear: 27,
            recentActivity: [
                .hearted(friendBook(spyFamily, favoritedAt: daysAgo(2), activity: 2), at: daysAgo(2)),
                .reading(friendBook(shared("frieren-14"), activity: 4), at: daysAgo(4)),
                .finished(friendBook(shared("blacksad-7"), activity: 8), at: daysAgo(8)),
            ]
        ),
        Friend(
            userId: "camille", firstName: camille, since: daysAgo(120), bookCount: 64,
            favoriteCount: 7, readingCount: 1, toReadCount: 14, readThisYear: 18,
            recentActivity: [
                .finished(friendBook(shared("veiller-sur-elle"), activity: 5), at: daysAgo(5)),
                .reading(friendBook(shared("monte-cristo"), activity: 9), at: daysAgo(9)),
            ]
        ),
    ]

    static var picks: FriendPicks {
        let leaLover = FriendLovers.Lover(userId: "lea", firstName: lea)
        let hugoLover = FriendLovers.Lover(userId: "hugo", firstName: hugo)
        let camilleLover = FriendLovers.Lover(userId: "camille", firstName: camille)
        return FriendPicks(books: [
            LovedBook(book: friendBook(shared("nuit-des-temps"), activity: 1),
                      lovers: FriendLovers(friends: [leaLover, hugoLover], lovedByMany: true)),
            LovedBook(book: friendBook(shared("seul-sur-mars"), activity: 2),
                      lovers: FriendLovers(friends: [hugoLover], lovedByMany: false)),
            LovedBook(book: friendBook(shared("furtifs"), activity: 3),
                      lovers: FriendLovers(friends: [leaLover, camilleLover], lovedByMany: true)),
        ])
    }

    /// The reader's own shelf as their friends see it.
    static var myShelf: FriendProfile {
        let reading = books.filter { $0.status == .reading }
            .sorted { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) }
        let read = shelved.filter { $0.status == .read }
        let year = calendar.component(.year, from: .now)
        return FriendProfile(
            userId: "me",
            firstName: firstName,
            reading: reading.map { friendBook($0, activity: 1) },
            pile: books.filter { $0.status == .toRead }.map { friendBook($0, activity: 30) },
            favorites: books.filter(\.favorite).map { friendBook($0, favoritedAt: $0.finishedAt, activity: 10) },
            sagas: [],
            lastFinished: read.first.map { friendBook($0, activity: 5) },
            lastAdded: shelved.first.map { friendBook($0, activity: 1) },
            bookCount: books.count,
            readThisYear: read.filter {
                $0.finishedAt.map { calendar.component(.year, from: $0) } == year
            }.count
        )
    }

    // MARK: - Scan

    /// What the scan of a cover answers: the paperback of a saga the reader
    /// already hears, which joins it as its first volume.
    static let scanned = ScannedBook(
        recognized: true,
        title: local("Hypérion", "Hyperion"),
        authors: ["Dan Simmons"],
        format: .book,
        media: [.print],
        publisher: local("Robert Laffont", "Del Rey"),
        firstPublishedIn: 1989,
        synopsis: local(
            """
            Sur la planète Hypérion, aux confins de l'Hégémonie, se dressent les Tombeaux du \
            Temps, gardés par le Gritche, une créature de métal et de lames. À la veille d'une \
            guerre, sept pèlerins partent à leur rencontre, et chacun raconte en chemin ce qui \
            l'y mène.
            """,
            """
            On the world of Hyperion, at the edge of the Hegemony, stand the Time Tombs, \
            guarded by the Shrike, a creature of metal and blades. On the eve of war, seven \
            pilgrims set out to meet it, and on the way each tells what brings them there.
            """
        ),
        genre: .scienceFiction,
        subgenres: ["Space opera"],
        pageCount: local(576, 482),
        language: language,
        coverURL: cover("hyperion"),
        series: SeriesMembership(
            id: "cantos-hyperion", name: local("Les Cantos d'Hypérion", "Hyperion Cantos"), volume: 1,
            kind: .main
        )
    )

    // MARK: - Subscription

    /// The two plans as App Store Connect sells them in France, and in the
    /// United States.
    static let offers = [
        PremiumOffer(
            id: SubscriptionProducts.yearly, name: local("Premium annuel", "Premium Yearly"),
            displayPrice: local("17,99 €", "$14.99"), price: Decimal(string: local("17.99", "14.99"))!,
            trial: local("1 mois offert", "1 month free")
        ),
        PremiumOffer(
            id: SubscriptionProducts.monthly, name: local("Premium mensuel", "Premium Monthly"),
            displayPrice: local("1,99 €", "$1.99"), price: Decimal(string: "1.99")!
        ),
    ]

    static let entitlement = EntitlementState(
        isPremium: false, appAccountToken: nil, productId: nil, expiresOn: nil
    )

    static let quota = QuotaState(
        isPremium: false, used: 3, limit: 5, remaining: 2, welcomeRemaining: 38,
        totalRemaining: 40, renewsOn: calendar.date(byAdding: .day, value: 29, to: .now)
    )

    // MARK: - The month's discoveries

    /// A book Claude chose this month, as the captures show it: on no shelf
    /// yet, drawn from a book the reader loved, with what its page tells.
    private struct Pick {
        let slug: String
        let title: String
        let original: String
        let authors: [String]
        let short: String
        let reason: String
        let reference: SuggestionReference
        let publisher: String
        let year: Int
        let pages: Int
        let subgenre: String
        let synopsis: String
    }

    private static func reference(
        _ bookId: String, _ title: String, cover slug: String, rating: Double, favorite: Bool = false,
        series: String? = nil
    ) -> SuggestionReference {
        SuggestionReference(
            bookId: bookId, seriesId: series, title: title, favorite: favorite, rating: rating,
            viaSeries: series != nil, coverURL: cover(slug),
            citesSaga: series != nil
        )
    }

    private static let discoveryPicks: [Pick] = [
        Pick(
            slug: "toile-du-temps", title: local("Dans la toile du temps", "Children of Time"),
            original: "Children of Time", authors: ["Adrian Tchaikovsky"],
            short: local("comme Projet Dernière Chance", "like Project Hail Mary"),
            reason: local(
                "Un premier contact vertigineux, raconté du côté des araignées : l'émerveillement scientifique de Projet Dernière Chance, à l'échelle de millénaires.",
                "A dizzying first contact, told from the spiders' side: the scientific wonder of Project Hail Mary, across millennia."
            ),
            reference: reference(
                "projet-derniere-chance", local("Projet Dernière Chance", "Project Hail Mary"),
                cover: "projet-derniere-chance", rating: 5, favorite: true
            ),
            publisher: local("Denoël", "Orbit"), year: 2015, pages: local(576, 600),
            subgenre: local("Premier contact", "First contact"),
            synopsis: local(
                """
                Les derniers humains fuient une Terre morte et visent une planète terraformée \
                il y a des siècles. Ils ignorent qu'une autre espèce y a pris son essor, \
                génération après génération, et qu'elle les attend.
                """,
                """
                The last humans flee a dead Earth for a planet terraformed centuries ago. They \
                do not know that another species has risen there, generation after generation, \
                and that it is waiting for them.
                """
            )
        ),
        Pick(
            slug: "leviathan", title: local("L'Éveil du Léviathan", "Leviathan Wakes"),
            original: "Leviathan Wakes", authors: ["James S. A. Corey"],
            short: local("comme Les Cantos d'Hypérion", "like the Hyperion Cantos"),
            reason: local(
                "Un space opera ample et politique, porté par un équipage attachant, pour qui a aimé le souffle des Cantos d'Hypérion.",
                "A sweeping, political space opera carried by a crew you grow fond of, for a reader who loved the scope of the Hyperion Cantos."
            ),
            reference: reference(
                "cantos-hyperion-1", local("Les Cantos d'Hypérion", "Hyperion Cantos"),
                cover: "hyperion-audio-01", rating: 5, series: "cantos-hyperion"
            ),
            publisher: local("Actes Sud", "Orbit"), year: 2011, pages: local(672, 592),
            subgenre: "Space opera",
            synopsis: local(
                """
                Dans un système solaire colonisé, l'équipage d'un remorqueur de glace découvre \
                un vaisseau abandonné, et un secret qui pourrait déclencher la guerre entre la \
                Terre, Mars et la Ceinture.
                """,
                """
                In a colonised solar system, the crew of an ice hauler finds a derelict ship, \
                and a secret that could start a war between Earth, Mars and the Belt.
                """
            )
        ),
        Pick(
            slug: "ubik", title: "Ubik", original: "Ubik", authors: ["Philip K. Dick"],
            short: local("comme Neuromancien", "like Neuromancer"),
            reason: local(
                "Une réalité qui se dérobe page après page : le vertige paranoïaque que vous avez aimé dans Neuromancien.",
                "A reality that slips away page after page: the paranoid vertigo you liked in Neuromancer."
            ),
            reference: reference(
                "neuromancien", local("Neuromancien", "Neuromancer"), cover: "neuromancien", rating: 4
            ),
            publisher: local("J'ai lu", "Mariner"), year: 1969, pages: local(288, 288),
            subgenre: local("Réalité truquée", "Simulated reality"),
            synopsis: local(
                """
                Après un attentat sur la Lune, Joe Chip voit le monde se défaire autour de lui : \
                les pièces vieillissent, le temps recule, et des messages lui parviennent d'un \
                patron qu'il croyait mort.
                """,
                """
                After a bombing on the Moon, Joe Chip watches the world come undone around him: \
                coins age, time runs backwards, and messages reach him from a boss he thought \
                was dead.
                """
            )
        ),
        Pick(
            slug: "main-gauche-nuit",
            title: local("La Main gauche de la nuit", "The Left Hand of Darkness"),
            original: "The Left Hand of Darkness", authors: ["Ursula K. Le Guin"],
            short: local("comme Fondation", "like Foundation"),
            reason: local(
                "Une planète gelée, un envoyé seul et toute une société à comprendre : la science-fiction des idées, dans la lignée de Fondation.",
                "A frozen world, a lone envoy and a whole society to understand: science fiction of ideas, in the line of Foundation."
            ),
            reference: reference("fondation", local("Fondation", "Foundation"), cover: "fondation", rating: 4),
            publisher: local("Le Livre de Poche", "Ace"), year: 1969, pages: local(352, 304),
            subgenre: local("Anthropologique", "Anthropological"),
            synopsis: local(
                """
                Envoyé seul sur Nivôse, un monde de glace dont les habitants n'ont pas de sexe \
                fixe, Genly Aï doit convaincre ses rois de rejoindre une alliance de planètes.
                """,
                """
                Sent alone to Winter, an ice world whose people have no fixed sex, Genly Ai \
                must persuade its rulers to join an alliance of worlds.
                """
            )
        ),
    ]

    /// This month's selection, all four still to be seen.
    /// On with `-showcase-unrated`: the shelf as if nothing on it were
    /// rated, so the month's selection asks for a rating instead.
    static let isUnrated = ProcessInfo.processInfo.arguments.contains("-showcase-unrated")

    /// On with `-showcase-month-done`: every discovery of the month answered.
    static let isMonthDone = ProcessInfo.processInfo.arguments.contains("-showcase-month-done")

    static var monthlyDiscoveries: MonthlyDiscoveries {
        if isMonthDone {
            return MonthlyDiscoveries(month: MonthlyDiscoveries.month(of: .now), status: .ready, suggestions: [])
        }
        if isUnrated {
            return MonthlyDiscoveries(
                month: MonthlyDiscoveries.month(of: .now), status: .none, suggestions: [], needsRatings: true
            )
        }
        return MonthlyDiscoveries(
            month: MonthlyDiscoveries.month(of: .now),
            suggestions: discoveryPicks.map { pick in
                Suggestion(
                    id: pick.slug, format: .book, title: pick.title, originalTitle: pick.original,
                    originalLanguage: .en, authors: pick.authors, reason: pick.reason, short: pick.short,
                    references: [pick.reference], state: .available, watched: false, date: nil,
                    coverURL: cover(pick.slug), storeURL: nil, awaitableFormats: [.audiobook],
                    awaitedEditionId: nil
                )
            }
        )
    }

    /// What a suggestion's page tells once described.
    static func description(of seed: ReleaseSeed) -> ReleaseDescription {
        let pick = discoveryPicks.first { $0.title == seed.title }
        return ReleaseDescription(
            book: ScannedBook(
                recognized: true,
                title: seed.title,
                authors: seed.authors,
                format: .book,
                publisher: pick?.publisher,
                firstPublishedIn: pick?.year,
                synopsis: pick?.synopsis,
                genre: .scienceFiction,
                subgenres: pick.map { [$0.subgenre] } ?? [],
                pageCount: pick?.pages,
                language: language,
                coverURL: seed.coverURL
            ),
            narrators: [],
            durationMinutes: nil
        )
    }
}
#endif
