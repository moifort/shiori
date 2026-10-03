#if DEBUG
import Foundation

/// The library the App Store captures show, with the app running on it instead
/// of on the server.
///
/// `scripts/screenshots.sh` launches the app with `-showcase`: the Apple
/// sign-in and the onboarding are skipped, and every read the captured
/// screens make answers from here (`ShioriUITests/ScreenshotTest`). Nothing
/// else changes: the pages are the real ones, drawn from real data types.
///
/// One list of books is the source of everything: the dashboard's figures, the
/// sagas and their strips, the friends' shelves are all derived from it, so no
/// screen can contradict another. The books are real, with the covers of their
/// French editions, fetched once by `scripts/showcase-covers.ts` into
/// `screenshots/covers/` and read off the Mac's disk, which the simulator sees.
///
/// Debug-only by construction: the Release archive the App Store gets
/// compiles none of it.
enum Showcase {
    static let isOn = ProcessInfo.processInfo.arguments.contains("-showcase")

    /// The reader the captures belong to.
    static let firstName = "Thibaut"

    // MARK: - Covers

    private static let covers = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // Shared/
        .deletingLastPathComponent() // Shiori/
        .deletingLastPathComponent() // ios/
        .deletingLastPathComponent() // repository root
        .appending(path: "screenshots/covers", directoryHint: .isDirectory)

    /// A cover by the name `showcase-covers.ts` saved it under. Nil when that
    /// file is not on disk, so a missing cover draws initials, as in the app.
    static func cover(_ slug: String) -> URL? {
        let url = covers.appending(path: "\(slug).jpg")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: - Dates

    private static let calendar = Calendar.current

    private static func daysAgo(_ days: Double) -> Date {
        .now.addingTimeInterval(-days * 86400)
    }

    /// `YYYY-MM-DD`, some days from today: how the release watch dates a volume.
    private static func day(_ offset: Int) -> String {
        let date = calendar.date(byAdding: .day, value: offset, to: .now) ?? .now
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    // MARK: - Sagas

    /// A saga on the reader's shelf, and what the release watch knows of it.
    struct Saga {
        let id: String
        let name: String
        let authors: [String]
        var format: BookFormat = .book
        var media: [BookMedium] = [.print]
        var publisher: String?
        let genre: BookGenre
        var subgenres: [String] = []
        var pages: Int?
        var minutes: [Int] = []
        var narrators: [String] = []
        /// The titles of the volumes that carry one; the others are "Name, tome N".
        var titles: [Int: String] = [:]
        /// Every volume out, owned or not.
        let published: Int
        /// The volumes the reader holds, from the first.
        let owned: Int
        /// The volumes read, from the first, finished between these two days ago.
        let read: Int
        let readBetween: (from: Double, to: Double)
        /// The volume after the last read, picked up that many days ago.
        var readingSince: Double?
        var listeningProgress: Int?
        /// The next volume announced, that many days from today.
        var announced: (number: Int, title: String?, inDays: Int)?
        /// The last volume out, that many days ago, when it is news.
        var outDaysAgo: Int?
        var rating: Int?
        var favorite = false
        /// The cover slug of a volume, by number.
        let slug: String
        var firstPublishedIn: Int?
        var description: String?

        var isAudio: Bool { format == .audiobook }

        func title(_ number: Int) -> String {
            titles[number] ?? "\(name), tome \(number)"
        }

        func coverSlug(_ number: Int) -> String {
            "\(slug)-\(String(format: "%02d", number))"
        }
    }

    static let sagas: [Saga] = [
        Saga(
            id: "one-piece", name: "One Piece", authors: ["Eiichirō Oda"], format: .manga,
            publisher: "Glénat", genre: .adventure, subgenres: ["Shōnen", "Pirates"], pages: 208,
            published: 113, owned: 113, read: 112, readBetween: (900, 20), readingSince: 3,
            announced: (114, nil, 68), rating: 5, favorite: true, slug: "one-piece",
            firstPublishedIn: 1997,
            description: """
            Monkey D. Luffy, un garçon au corps élastique, prend la mer pour trouver le One \
            Piece, le trésor légendaire de Gol D. Roger, et devenir le roi des pirates.
            """
        ),
        Saga(
            id: "frieren", name: "Frieren", authors: ["Kanehito Yamada", "Tsukasa Abe"],
            format: .manga, publisher: "Ki-oon", genre: .fantasy, subgenres: ["Shōnen"], pages: 192,
            published: 15, owned: 14, read: 14, readBetween: (420, 16),
            outDaysAgo: 4, rating: 5, favorite: true, slug: "frieren",
            firstPublishedIn: 2020
        ),
        Saga(
            id: "blue-lock", name: "Blue Lock", authors: ["Muneyuki Kaneshiro", "Yusuke Nomura"],
            format: .manga, publisher: "Pika", genre: .adventure, subgenres: ["Sport", "Shōnen"],
            pages: 192, published: 34, owned: 34, read: 34, readBetween: (610, 5),
            announced: (35, nil, 12), rating: 4, slug: "blue-lock", firstPublishedIn: 2018
        ),
        Saga(
            id: "dungeon-crawler-carl", name: "Dungeon Crawler Carl", authors: ["Matt Dinniman"],
            media: [.digital], genre: .scienceFiction, subgenres: ["LitRPG"], pages: 480,
            titles: [
                1: "Dungeon Crawler Carl", 2: "L'Ogive du jugement dernier",
                3: "Le Livre de recettes de l'Anarchiste", 4: "Le Portail des dieux infernaux",
                5: "La Mascarade du boucher", 6: "L'Œil de la Veuve du Chaos",
            ],
            published: 5, owned: 5, read: 5, readBetween: (300, 38),
            announced: (6, nil, 47), rating: 5, favorite: true, slug: "dcc", firstPublishedIn: 2020,
            description: """
            Quand la Terre est rasée pour devenir le décor d'un jeu télévisé intergalactique, \
            Carl et la chatte de son ex, Princesse Beignet, n'ont qu'une issue : descendre les \
            dix-huit étages du donjon, sous l'œil de milliards de spectateurs.
            """
        ),
        Saga(
            id: "blacksad", name: "Blacksad", authors: ["Juan Díaz Canales", "Juanjo Guarnido"],
            format: .bandeDessinee, publisher: "Dargaud", genre: .crime, subgenres: ["Noir"],
            pages: 56,
            titles: [
                1: "Quelque part entre les ombres", 2: "Arctic-Nation", 3: "Âme rouge",
                4: "L'Enfer, le silence", 5: "Amarillo", 6: "Alors, tout tombe — Première partie",
                7: "Alors, tout tombe — Seconde partie",
            ],
            published: 7, owned: 7, read: 7, readBetween: (1500, 27), rating: 5, favorite: true,
            slug: "blacksad", firstPublishedIn: 2000
        ),
        Saga(
            id: "chateau-des-animaux", name: "Le Château des Animaux",
            authors: ["Xavier Dorison", "Félix Delep"], format: .bandeDessinee,
            publisher: "Casterman", genre: .adventure, subgenres: ["Fable"], pages: 72,
            titles: [
                1: "Miss Bengalore", 2: "Les Marguerites de l'hiver", 3: "La Nuit des justes",
                4: "Le Sang du roi",
            ],
            published: 4, owned: 4, read: 4, readBetween: (400, 52), rating: 4,
            slug: "chateau-animaux", firstPublishedIn: 2019
        ),
        Saga(
            id: "cantos-hyperion", name: "Les Cantos d'Hypérion", authors: ["Dan Simmons"],
            format: .audiobook, media: [.digital], genre: .scienceFiction,
            subgenres: ["Space opera"], minutes: [1265, 1150, 1310, 1455],
            narrators: ["Frédéric Kneip"],
            titles: [1: "Hypérion", 2: "La Chute d'Hypérion", 3: "Endymion", 4: "L'Éveil d'Endymion"],
            published: 4, owned: 4, read: 2, readBetween: (130, 64), readingSince: 9,
            listeningProgress: 46, rating: 5, slug: "hyperion-audio", firstPublishedIn: 1989
        ),
    ]

    // MARK: - The books

    /// Every book on the reader's shelf.
    static let books: [Book] = sagaVolumes + singles

    private static var sagaVolumes: [Book] {
        sagas.flatMap { saga in
            (1...saga.owned).map { number in
                volume(number, of: saga)
            }
        }
    }

    private static func volume(_ number: Int, of saga: Saga) -> Book {
        let status: ReadingStatus
        var startedAt: Date?
        var finishedAt: Date?
        if number <= saga.read {
            status = .read
            let span = saga.readBetween.from - saga.readBetween.to
            let share = saga.read == 1 ? 1 : Double(number - 1) / Double(saga.read - 1)
            let finished = saga.readBetween.from - span * share
            finishedAt = daysAgo(finished)
            startedAt = daysAgo(finished + (saga.isAudio ? 12 : 2))
        } else if number == saga.read + 1, let since = saga.readingSince {
            status = .reading
            startedAt = daysAgo(since)
        } else {
            status = .toRead
        }
        let addedAt = startedAt.map { $0.addingTimeInterval(-3 * 86400) } ?? daysAgo(45)
        return Book(
            id: "\(saga.id)-\(number)",
            title: saga.title(number),
            authors: saga.authors,
            format: saga.format,
            media: saga.media,
            publisher: saga.publisher,
            firstPublishedIn: saga.firstPublishedIn.map { $0 + (number - 1) / 3 },
            genre: saga.genre,
            subgenres: saga.subgenres,
            pageCount: saga.pages,
            durationMinutes: saga.minutes.indices.contains(number - 1) ? saga.minutes[number - 1] : nil,
            narrators: saga.narrators,
            listeningProgress: status == .reading ? saga.listeningProgress : nil,
            language: .fr,
            series: SeriesMembership(id: saga.id, name: saga.name, volume: number, kind: .main),
            coverURL: cover(saga.coverSlug(number)),
            status: status,
            seriesRating: saga.rating,
            addedAt: addedAt,
            startedAt: startedAt,
            finishedAt: finishedAt,
            shelvedAt: finishedAt ?? startedAt ?? addedAt
        )
    }

    /// A book read, being read, or waiting, with what the reader thought of it.
    private static func single(
        _ id: String,
        _ title: String,
        _ authors: [String],
        publisher: String,
        year: Int,
        genre: BookGenre,
        subgenres: [String] = [],
        pages: Int,
        series: (name: String, volume: Int)? = nil,
        status: ReadingStatus,
        days: Double,
        rating: Int? = nil,
        favorite: Bool = false,
        note: String? = nil,
        synopsis: String? = nil,
        recommendation: BookRecommendation? = nil
    ) -> Book {
        let finishedAt = status == .read ? daysAgo(days) : nil
        let startedAt: Date? = switch status {
        case .read: daysAgo(days + Double(pages) / 45)
        case .reading: daysAgo(days)
        default: nil
        }
        let addedAt = startedAt.map { $0.addingTimeInterval(-6 * 86400) } ?? daysAgo(days)
        return Book(
            id: id,
            title: title,
            authors: authors,
            publisher: publisher,
            firstPublishedIn: year,
            synopsis: synopsis,
            genre: genre,
            subgenres: subgenres,
            pageCount: pages,
            language: .fr,
            series: series.map {
                SeriesMembership(id: $0.name, name: $0.name, volume: $0.volume, kind: .main)
            },
            coverURL: cover(id),
            status: status,
            rating: rating,
            favorite: favorite,
            note: note,
            recommendation: recommendation,
            addedAt: addedAt,
            startedAt: startedAt,
            finishedAt: finishedAt,
            shelvedAt: finishedAt ?? startedAt ?? addedAt
        )
    }

    /// The book the captures open: read lately, loved, with a note.
    static let featured = single(
        "projet-derniere-chance", "Projet Dernière Chance", ["Andy Weir"],
        publisher: "Bragelonne", year: 2021, genre: .scienceFiction,
        subgenres: ["Hard SF", "Premier contact"], pages: 496, status: .read, days: 11,
        rating: 5, favorite: true,
        note: "Rocky ! Le meilleur duo de la SF depuis des années. Lu d'une traite, à relire en audio.",
        synopsis: """
        Ryland Grace se réveille seul à bord d'un vaisseau, sans le moindre souvenir de \
        qui il est ni de sa mission. Peu à peu, la mémoire lui revient : il est le dernier \
        espoir de l'humanité, à des années-lumière de la Terre. Et il n'est peut-être pas \
        aussi seul qu'il le croyait.
        """,
        recommendation: BookRecommendation(recommenderName: "Léa", comment: "Tu vas adorer Rocky.")
    )

    private static let singles: [Book] = [
        featured,
        single(
            "horde-du-contrevent", "La Horde du Contrevent", ["Alain Damasio"],
            publisher: "Folio SF", year: 2004, genre: .fantasy, subgenres: ["Aventure"],
            pages: 736, status: .read, days: 60, rating: 5, favorite: true,
            note: "Le plus beau livre français de l'imaginaire. La typographie des pages en vent !"
        ),
        single(
            "veiller-sur-elle", "Veiller sur elle", ["Jean-Baptiste Andrea"],
            publisher: "L'Iconoclaste", year: 2023, genre: .literaryFiction, pages: 592,
            status: .read, days: 33, rating: 4
        ),
        single(
            "shibumi", "Shibumi", ["Trevanian"], publisher: "Gallmeister", year: 1979,
            genre: .thriller, subgenres: ["Espionnage"], pages: 512, status: .read, days: 90,
            rating: 5, favorite: true
        ),
        single(
            "dune", "Dune", ["Frank Herbert"], publisher: "Robert Laffont", year: 1965,
            genre: .scienceFiction, pages: 832, series: ("Dune", 1), status: .read, days: 45,
            rating: 4
        ),
        single(
            "messie-de-dune", "Le Messie de Dune", ["Frank Herbert"], publisher: "Robert Laffont",
            year: 1969, genre: .scienceFiction, pages: 384, series: ("Dune", 2), status: .toRead,
            days: 44
        ),
        single(
            "nom-du-vent", "Le Nom du vent", ["Patrick Rothfuss"], publisher: "Bragelonne",
            year: 2007, genre: .fantasy, pages: 864, series: ("Chronique du tueur de roi", 1),
            status: .read, days: 210, rating: 5, favorite: true
        ),
        single(
            "peur-du-sage", "La Peur du sage", ["Patrick Rothfuss"], publisher: "Bragelonne",
            year: 2011, genre: .fantasy, pages: 720, series: ("Chronique du tueur de roi", 2),
            status: .reading, days: 14
        ),
        single(
            "trois-corps", "Le Problème à trois corps", ["Liu Cixin"], publisher: "Actes Sud",
            year: 2008, genre: .scienceFiction, pages: 432, series: ("Le Problème à trois corps", 1),
            status: .read, days: 500, rating: 4
        ),
        single(
            "foret-sombre", "La Forêt sombre", ["Liu Cixin"], publisher: "Actes Sud", year: 2008,
            genre: .scienceFiction, pages: 640, series: ("Le Problème à trois corps", 2),
            status: .read, days: 470, rating: 5
        ),
        single(
            "mort-immortelle", "La Mort immortelle", ["Liu Cixin"], publisher: "Actes Sud",
            year: 2010, genre: .scienceFiction, pages: 816,
            series: ("Le Problème à trois corps", 3), status: .toRead, days: 460
        ),
        single(
            "fondation", "Fondation", ["Isaac Asimov"], publisher: "Folio SF", year: 1951,
            genre: .scienceFiction, pages: 416, status: .read, days: 700, rating: 4
        ),
        single(
            "fourth-wing", "Fourth Wing", ["Rebecca Yarros"], publisher: "Hugo Roman", year: 2023,
            genre: .fantasy, subgenres: ["Romantasy"], pages: 640, status: .read, days: 150,
            rating: 4
        ),
        single(
            "sapiens", "Sapiens", ["Yuval Noah Harari"], publisher: "Albin Michel", year: 2015,
            genre: .history, pages: 512, status: .read, days: 260, rating: 4
        ),
        single(
            "monte-cristo", "Le Comte de Monte-Cristo", ["Alexandre Dumas"],
            publisher: "Le Livre de Poche", year: 1844, genre: .adventure, pages: 1504,
            status: .toRead, days: 120
        ),
        single(
            "demain-et-demain", "Demain, et demain, et demain", ["Gabrielle Zevin"],
            publisher: "Calmann-Lévy", year: 2022, genre: .literaryFiction, pages: 528,
            status: .toRead, days: 30
        ),
        single(
            "furtifs", "Les Furtifs", ["Alain Damasio"], publisher: "La Volte", year: 2019,
            genre: .scienceFiction, pages: 704, status: .toRead, days: 70
        ),
    ]

    /// Newest on the shelf first, as the server orders the Library tab.
    static var shelved: [Book] {
        books.sorted { ($0.shelvedAt ?? .distantPast) > ($1.shelvedAt ?? .distantPast) }
    }

    static func book(id: String) -> Book? {
        books.first { $0.id == id }
    }

    // MARK: - Library

    static func libraryPage(mode: LibraryMode, status: ReadingStatus?, limit: Int, after: String?)
        -> LibraryPageResult
    {
        let matching = shelved.filter { book in
            (mode != .favorites || book.favorite) && (status == nil || book.status == status)
        }
        let start = after.flatMap { id in matching.firstIndex { $0.id == id }.map { $0 + 1 } } ?? 0
        let page = Array(matching.dropFirst(start).prefix(limit))
        return LibraryPageResult(books: page, hasMore: start + page.count < matching.count)
    }

    // MARK: - Series

    /// The saga's catalogue: every volume out, then the one announced.
    static func spine(of saga: Saga) -> [Volume] {
        var spine = (1...saga.published).map { number in
            Volume(
                number: number,
                title: saga.title(number),
                publishedIn: saga.firstPublishedIn,
                kind: .main,
                releases: number > saga.owned
                    ? [VolumeRelease(
                        language: .fr,
                        date: day(-(saga.outDaysAgo ?? 30)),
                        title: saga.title(number),
                        coverURL: cover(saga.coverSlug(number))
                    )]
                    : []
            )
        }
        if let announced = saga.announced {
            spine.append(Volume(
                number: announced.number,
                title: announced.title ?? saga.title(announced.number),
                publishedIn: nil,
                kind: .main,
                releases: [VolumeRelease(
                    language: .fr,
                    date: day(announced.inDays),
                    title: announced.title ?? saga.title(announced.number),
                    coverURL: cover(saga.coverSlug(announced.number))
                )]
            ))
        }
        return spine
    }

    /// A saga as the Series tab draws it: its volumes on the shelf, and the
    /// catalogue's strip with the volume out the reader lacks and the one to come.
    static func followed(_ saga: Saga) -> FollowedSeries {
        let volumes = books.filter { $0.series?.id == saga.id }
        let spine = spine(of: saga)
        let readCount = volumes.filter { $0.status == .read }.count
        let state: SeriesState = readCount == saga.published && saga.announced == nil
            ? .complete
            : .inProgress
        return FollowedSeries(
            seriesId: saga.id,
            name: saga.name,
            isAudio: saga.isAudio,
            author: saga.authors.first,
            language: .fr,
            state: state,
            genre: saga.genre,
            ownedCount: volumes.count,
            shelvedAt: volumes.compactMap(\.shelvedAt).max(),
            volumes: volumes,
            strip: SeriesStripItem.strip(
                owned: volumes,
                spine: spine,
                currentYear: calendar.component(.year, from: .now),
                language: .fr
            ),
            isCatalogued: true,
            opinion: SeriesOpinion(seriesId: saga.id, rating: saga.rating, favorite: saga.favorite)
        )
    }

    static func seriesPage(limit: Int, offset: Int, mode: LibraryMode, state: SeriesState?)
        -> (items: [FollowedSeries], hasMore: Bool)
    {
        let all = sagas.map(followed)
            .filter { (mode != .favorites || $0.opinion?.favorite == true) && (state == nil || $0.state == state) }
            .sorted { ($0.shelvedAt ?? .distantPast) > ($1.shelvedAt ?? .distantPast) }
        let page = Array(all.dropFirst(offset).prefix(limit))
        return (page, offset + page.count < all.count)
    }

    /// The saga page: its catalogue, what the reader thinks of it, their volumes.
    static func seriesScreen(id: String) -> (series: BookSeries?, opinion: SeriesOpinion?, owned: [Book]) {
        guard let saga = sagas.first(where: { $0.id == id }) else { return (nil, nil, []) }
        return (
            series: BookSeries(
                id: saga.id,
                name: saga.name,
                author: saga.authors.joined(separator: ", "),
                description: saga.description,
                spine: spine(of: saga),
                isAudio: saga.isAudio
            ),
            opinion: SeriesOpinion(seriesId: saga.id, rating: saga.rating, favorite: saga.favorite),
            owned: books.filter { $0.series?.id == saga.id }
        )
    }

    /// The next volume the release watch found, under the saga's introduction.
    static func sagaReleases(seriesId: String) -> SagaReleases {
        let saga = sagas.first { $0.id == seriesId }
        return SagaReleases(
            watched: true,
            next: saga?.announced.map { announced in
                DiscoveredVolume(
                    number: announced.number,
                    title: announced.title ?? saga!.title(announced.number),
                    date: day(announced.inDays),
                    isbn13: nil,
                    coverURL: cover(saga!.coverSlug(announced.number))
                )
            }
        )
    }

    static func followedSeries(seriesId: String) -> FollowedSeries? {
        sagas.first { $0.id == seriesId }.map(followed)
    }

    // MARK: - Découvrir

    static func discovery(format: ReleaseFormat) -> DiscoveryPage {
        let rows = sagas
            .filter { $0.isAudio == (format == .audiobook) }
            .map { saga -> SagaDiscovery in
                let next = saga.announced.map { announced in
                    DiscoveredVolume(
                        number: announced.number,
                        title: announced.title ?? saga.title(announced.number),
                        date: day(announced.inDays),
                        isbn13: nil,
                        coverURL: cover(saga.coverSlug(announced.number))
                    )
                }
                let out = saga.outDaysAgo.map { days in
                    (saga.owned + 1...saga.published).map { number in
                        DiscoveredVolume(
                            number: number,
                            title: saga.title(number),
                            date: day(-days),
                            isbn13: nil,
                            coverURL: cover(saga.coverSlug(number))
                        )
                    }
                } ?? []
                return SagaDiscovery(
                    series: followed(saga),
                    releases: SagaReleases(watched: true, next: next),
                    missing: out.map(\.number),
                    recent: out.reversed()
                )
            }
        return DiscoveryPage(rows: rows, authors: [], unwatched: 0, followed: rows.count)
    }

    // MARK: - Dashboard

    /// The home screen's figures, counted off the shelf above the way the
    /// server counts them.
    static var dashboard: Dashboard {
        let year = calendar.component(.year, from: .now)
        let read = books.filter { $0.status == .read }
        func finishedYear(_ book: Book) -> Int? { book.finishedAt.map { calendar.component(.year, from: $0) } }
        let thisYear = read.filter { finishedYear($0) == year }
        let lastYearSoFar = read.filter { book in
            guard let finished = book.finishedAt, finishedYear(book) == year - 1 else { return false }
            return calendar.date(byAdding: .year, value: 1, to: finished).map { $0 <= .now } ?? false
        }
        let firstYear = read.compactMap(finishedYear).min() ?? year
        let rated = books.compactMap(\.rating)
        let pile = books.filter { $0.status == .toRead }
        let lastTwelveMonths = read.filter { ($0.finishedAt ?? .distantPast) > daysAgo(365) }.count
        let genres = Dictionary(grouping: read, by: \.genre).mapValues(\.count)
            .sorted { $0.value > $1.value }
        let topGenres = genres.prefix(4).map { Dashboard.GenreSlice(genre: $0.key, count: $0.value) }
        let others = genres.dropFirst(4).map(\.value).reduce(0, +)
        return Dashboard(
            currentYear: year,
            booksPerYear: (firstYear...year).map { year in
                .init(year: year, count: read.filter { finishedYear($0) == year }.count)
            },
            pagesPerMonth: (1...12).map { month in
                .init(month: month, pages: thisYear
                    .filter { calendar.component(.month, from: $0.finishedAt!) == month }
                    .compactMap(\.pageCount).reduce(0, +))
            },
            hoursPerMonth: (1...12).map { month in
                .init(month: month, hours: thisYear
                    .filter { calendar.component(.month, from: $0.finishedAt!) == month }
                    .compactMap(\.durationMinutes).reduce(0, +) / 60)
            },
            reading: books.filter { $0.status == .reading }
                .sorted { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) },
            lastFinished: read.max { ($0.finishedAt ?? .distantPast) < ($1.finishedAt ?? .distantPast) },
            booksRead: .init(current: thisYear.count, previous: lastYearSoFar.count),
            toReadCount: pile.count,
            readCount: read.count,
            monthsToClearPile: lastTwelveMonths == 0
                ? nil
                : max(1, Int((Double(pile.count) / (Double(lastTwelveMonths) / 12)).rounded(.up))),
            averageRating: rated.isEmpty ? nil : Double(rated.reduce(0, +)) / Double(rated.count),
            ratedCount: rated.count,
            genres: topGenres + (others > 0 ? [.init(genre: nil, count: others)] : []),
            series: sagas.map(followed).filter { $0.state == .inProgress }.map { series in
                let saga = sagas.first { $0.id == series.seriesId }
                return .init(
                    id: series.seriesId,
                    name: series.name,
                    isAudio: series.isAudio,
                    readCount: series.volumes.filter { $0.status == .read }.count,
                    totalCount: saga?.published ?? series.ownedCount,
                    rating: saga?.rating,
                    favorite: saga?.favorite ?? false
                )
            },
            favoriteCount: books.filter(\.favorite).count + sagas.filter(\.favorite).count,
            droppedCount: books.filter { $0.status == .dropped }.count,
            hasAudiobooks: books.contains { $0.format == .audiobook },
            hasPrintedBooks: true,
            libraryIsEmpty: false
        )
    }

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
    private static func theirs(
        _ id: String, _ title: String, _ authors: [String], format: BookFormat = .book,
        status: ReadingStatus, series: (name: String, volume: Int)? = nil
    ) -> Book {
        Book(
            id: "friend-\(id)",
            title: title,
            authors: authors,
            format: format,
            language: .fr,
            series: series.map { SeriesMembership(id: $0.name, name: $0.name, volume: $0.volume, kind: .main) },
            coverURL: cover(id),
            status: status
        )
    }

    private static let sorceleur = theirs(
        "sorceleur-01", "Le Dernier Vœu", ["Andrzej Sapkowski"], status: .read, series: ("Sorceleur", 1)
    )
    private static let spyFamily = theirs(
        "spy-family-01", "Spy x Family, tome 1", ["Tatsuya Endo"], format: .manga, status: .read,
        series: ("Spy x Family", 1)
    )

    private static func shared(_ id: String) -> Book {
        guard let book = book(id: id) else { fatalError("no showcase book \(id)") }
        return book
    }

    static let friends: [Friend] = [
        Friend(
            userId: "lea", firstName: "Léa", since: daysAgo(400), bookCount: 186, favoriteCount: 23,
            readingCount: 2, toReadCount: 31, readThisYear: 41,
            recentActivity: [
                .hearted(friendBook(sorceleur, favoritedAt: daysAgo(1), activity: 1), at: daysAgo(1)),
                .finished(friendBook(shared("horde-du-contrevent"), activity: 3), at: daysAgo(3)),
                .reading(friendBook(shared("furtifs"), activity: 2), at: daysAgo(2)),
                .added(friendBook(shared("demain-et-demain"), activity: 6), at: daysAgo(6)),
            ]
        ),
        Friend(
            userId: "hugo", firstName: "Hugo", since: daysAgo(250), bookCount: 142,
            favoriteCount: 12, readingCount: 1, toReadCount: 9, readThisYear: 27,
            recentActivity: [
                .hearted(friendBook(spyFamily, favoritedAt: daysAgo(2), activity: 2), at: daysAgo(2)),
                .reading(friendBook(shared("frieren-14"), activity: 4), at: daysAgo(4)),
                .finished(friendBook(shared("blacksad-7"), activity: 8), at: daysAgo(8)),
            ]
        ),
        Friend(
            userId: "camille", firstName: "Camille", since: daysAgo(120), bookCount: 64,
            favoriteCount: 7, readingCount: 1, toReadCount: 14, readThisYear: 18,
            recentActivity: [
                .finished(friendBook(shared("veiller-sur-elle"), activity: 5), at: daysAgo(5)),
                .reading(friendBook(shared("monte-cristo"), activity: 9), at: daysAgo(9)),
            ]
        ),
    ]

    static var recentFavorites: [FriendFavorite] {
        [
            FriendFavorite(friendId: "lea", friendName: "Léa", favoritedAt: daysAgo(1),
                           book: friendBook(sorceleur, favoritedAt: daysAgo(1), activity: 1)),
            FriendFavorite(friendId: "hugo", friendName: "Hugo", favoritedAt: daysAgo(2),
                           book: friendBook(spyFamily, favoritedAt: daysAgo(2), activity: 2)),
            FriendFavorite(friendId: "lea", friendName: "Léa", favoritedAt: daysAgo(4),
                           book: friendBook(shared("horde-du-contrevent"), favoritedAt: daysAgo(4), activity: 4)),
            FriendFavorite(friendId: "camille", friendName: "Camille", favoritedAt: daysAgo(6),
                           book: friendBook(shared("veiller-sur-elle"), favoritedAt: daysAgo(6), activity: 6)),
        ]
    }

    static var picks: FriendPicks {
        let lea = FriendLovers.Lover(userId: "lea", firstName: "Léa")
        let hugo = FriendLovers.Lover(userId: "hugo", firstName: "Hugo")
        let camille = FriendLovers.Lover(userId: "camille", firstName: "Camille")
        return FriendPicks(books: [
            LovedBook(book: friendBook(sorceleur, activity: 1),
                      lovers: FriendLovers(friends: [lea, hugo], lovedByMany: true)),
            LovedBook(book: friendBook(spyFamily, activity: 2),
                      lovers: FriendLovers(friends: [hugo], lovedByMany: false)),
            LovedBook(book: friendBook(shared("furtifs"), activity: 3),
                      lovers: FriendLovers(friends: [lea, camille], lovedByMany: true)),
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
        title: "Hypérion",
        authors: ["Dan Simmons"],
        format: .book,
        media: [.print],
        publisher: "Robert Laffont",
        firstPublishedIn: 1989,
        synopsis: """
        Sur la planète Hypérion, aux confins de l'Hégémonie, se dressent les Tombeaux du \
        Temps, gardés par le Gritche, une créature de métal et de lames. À la veille d'une \
        guerre, sept pèlerins partent à leur rencontre, et chacun raconte en chemin ce qui \
        l'y mène.
        """,
        genre: .scienceFiction,
        subgenres: ["Space opera"],
        pageCount: 576,
        language: .fr,
        coverURL: cover("hyperion"),
        series: SeriesMembership(
            id: "cantos-hyperion", name: "Les Cantos d'Hypérion", volume: 1, kind: .main
        )
    )

    // MARK: - Subscription

    /// The two plans as App Store Connect sells them in France.
    static let offers = [
        PremiumOffer(
            id: SubscriptionProducts.yearly, name: "Premium annuel", displayPrice: "17,99 €",
            price: Decimal(string: "17.99")!, trial: "1 mois offert"
        ),
        PremiumOffer(
            id: SubscriptionProducts.monthly, name: "Premium mensuel", displayPrice: "1,99 €",
            price: Decimal(string: "1.99")!
        ),
    ]

    static let entitlement = EntitlementState(
        isPremium: false, appAccountToken: nil, productId: nil, expiresOn: nil
    )

    static let quota = QuotaState(
        isPremium: false, used: 3, limit: 5, remaining: 2, welcomeRemaining: 38,
        totalRemaining: 40, renewsOn: calendar.date(byAdding: .day, value: 29, to: .now)
    )
}
#endif
