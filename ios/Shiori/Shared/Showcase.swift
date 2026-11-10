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
/// The English captures show the same shelf in its American editions: every
/// text a book carries is written twice, and the few French books with no
/// English edition give their place to others, under the same ids.
///
/// Debug-only by construction: the Release archive the App Store gets
/// compiles none of it.
enum Showcase {
    /// On when launched with `-showcase`, or on a simulator whose `showcase`
    /// default is set, so the app opens on the showcase from its icon too:
    /// `defaults write <data container>/Library/Preferences/com.polyforms.shiori.app showcase -bool YES`.
    static let isOn = ProcessInfo.processInfo.arguments.contains("-showcase")
        || UserDefaults.standard.bool(forKey: "showcase")

    /// The language the app runs in, which the captures are taken in.
    private static let isEnglish = Bundle.main.preferredLocalizations.first == "en"

    /// The French edition's text, or the English one's.
    static func local<T>(_ french: T, _ english: T) -> T {
        isEnglish ? english : french
    }

    /// The language every book of the shelf is in.
    static let language: BookLanguage = local(.fr, .en)

    /// The reader the captures belong to.
    static let firstName = local("Thibaut", "Alex")

    // MARK: - Covers

    static let covers = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // Shared/
        .deletingLastPathComponent() // Shiori/
        .deletingLastPathComponent() // ios/
        .deletingLastPathComponent() // repository root
        .appending(path: "screenshots/covers", directoryHint: .isDirectory)

    /// A cover by the name `showcase-covers.ts` saved it under: the American
    /// edition's in English, else the French one's. Nil when no file is on
    /// disk, so a missing cover draws initials, as in the app.
    static func cover(_ slug: String) -> URL? {
        let candidates = (isEnglish ? [covers.appending(path: "en/\(slug).jpg")] : [])
            + [covers.appending(path: "\(slug).jpg")]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    // MARK: - Dates

    static let calendar = Calendar.current

    static func daysAgo(_ days: Double) -> Date {
        .now.addingTimeInterval(-days * 86400)
    }

    /// `YYYY-MM-DD`, some days from today: how the release watch dates a volume.
    static func day(_ offset: Int) -> String {
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
        var rating: Double?
        var favorite = false
        /// The cover slug of a volume, by number.
        let slug: String
        var firstPublishedIn: Int?
        var description: String?

        var isAudio: Bool { format == .audiobook }

        func title(_ number: Int) -> String {
            titles[number] ?? local("\(name), tome \(number)", "\(name), Vol. \(number)")
        }

        func coverSlug(_ number: Int) -> String {
            "\(slug)-\(String(format: "%02d", number))"
        }
    }

    static let sagas: [Saga] = [
        Saga(
            id: "one-piece", name: "One Piece", authors: ["Eiichirō Oda"], format: .manga,
            publisher: local("Glénat", "Viz Media"), genre: .adventure, subgenres: ["Shōnen", "Pirates"], pages: 208,
            published: 113, owned: 10, read: 8, readBetween: (500, 20), readingSince: 30,
            announced: (114, nil, 68), rating: 5, favorite: true, slug: "one-piece",
            firstPublishedIn: 1997,
            description: local(
                """
                Monkey D. Luffy, un garçon au corps élastique, prend la mer pour trouver le One \
                Piece, le trésor légendaire de Gol D. Roger, et devenir le roi des pirates.
                """,
                """
                Monkey D. Luffy, a boy whose body stretches like rubber, sets out to sea to find \
                the One Piece, Gol D. Roger's legendary treasure, and become King of the Pirates.
                """
            )
        ),
        Saga(
            id: "frieren", name: local("Frieren", "Frieren: Beyond Journey’s End"),
            authors: ["Kanehito Yamada", "Tsukasa Abe"],
            format: .manga, publisher: local("Ki-oon", "Viz Media"), genre: .fantasy, subgenres: ["Shōnen"], pages: 192,
            published: 15, owned: 14, read: 14, readBetween: (420, 45), outDaysAgo: 9,
            rating: 5, favorite: true, slug: "frieren",
            firstPublishedIn: 2020
        ),
        Saga(
            id: "blue-lock", name: "Blue Lock", authors: ["Muneyuki Kaneshiro", "Yusuke Nomura"],
            format: .manga, publisher: local("Pika", "Kodansha"), genre: .adventure,
            subgenres: [local("Sport", "Sports"), "Shōnen"],
            pages: 192, published: 34, owned: 8, read: 6, readBetween: (610, 25),
            announced: (35, nil, 40), rating: 4, slug: "blue-lock", firstPublishedIn: 2018
        ),
        Saga(
            id: "dungeon-crawler-carl", name: "Dungeon Crawler Carl", authors: ["Matt Dinniman"],
            media: [.digital], genre: .scienceFiction, subgenres: ["LitRPG"], pages: 480,
            titles: local(
                [
                    1: "Dungeon Crawler Carl", 2: "L'Ogive du jugement dernier",
                    3: "Le Livre de recettes de l'Anarchiste", 4: "Le Portail des dieux infernaux",
                    5: "La Mascarade du boucher", 6: "L'Œil de la Veuve du Chaos",
                ],
                [
                    1: "Dungeon Crawler Carl", 2: "Carl’s Doomsday Scenario",
                    3: "The Dungeon Anarchist’s Cookbook", 4: "The Gate of the Feral Gods",
                    5: "The Butcher’s Masquerade", 6: "The Eye of the Bedlam Bride",
                ]
            ),
            published: 5, owned: 5, read: 5, readBetween: (300, 1),
            announced: (6, nil, 12), rating: 5, favorite: true, slug: "dcc", firstPublishedIn: 2020,
            description: local(
                """
                Quand la Terre est rasée pour devenir le décor d'un jeu télévisé intergalactique, \
                Carl et la chatte de son ex, Princesse Beignet, n'ont qu'une issue : descendre les \
                dix-huit étages du donjon, sous l'œil de milliards de spectateurs.
                """,
                """
                When Earth is razed to become the set of an intergalactic game show, Carl and his \
                ex-girlfriend's cat, Princess Donut, have one way out: down the eighteen floors \
                of the dungeon, under the eyes of billions of viewers.
                """
            )
        ),
        Saga(
            id: "blacksad", name: "Blacksad", authors: ["Juan Díaz Canales", "Juanjo Guarnido"],
            format: .bandeDessinee, publisher: local("Dargaud", "Dark Horse"), genre: .crime,
            subgenres: ["Noir"], pages: 56,
            titles: local(
                [
                    1: "Quelque part entre les ombres", 2: "Arctic-Nation", 3: "Âme rouge",
                    4: "L'Enfer, le silence", 5: "Amarillo", 6: "Alors, tout tombe — Première partie",
                    7: "Alors, tout tombe — Seconde partie",
                ],
                [
                    1: "Somewhere Within the Shadows", 2: "Arctic-Nation", 3: "Red Soul",
                    4: "A Silent Hell", 5: "Amarillo", 6: "They All Fall Down · Part One",
                    7: "They All Fall Down · Part Two",
                ]
            ),
            published: 7, owned: 7, read: 7, readBetween: (1500, 27), rating: 5, favorite: true,
            slug: "blacksad", firstPublishedIn: 2000
        ),
        Saga(
            // No American edition: Saga stands in for it in English.
            id: "chateau-des-animaux", name: local("Le Château des Animaux", "Saga"),
            authors: local(["Xavier Dorison", "Félix Delep"], ["Brian K. Vaughan", "Fiona Staples"]),
            format: local(.bandeDessinee, .comic),
            publisher: local("Casterman", "Image Comics"), genre: .adventure,
            subgenres: [local("Fable", "Space opera")], pages: local(72, 160),
            titles: local([
                1: "Miss Bengalore", 2: "Les Marguerites de l'hiver", 3: "La Nuit des justes",
                4: "Le Sang du roi",
            ], [:]),
            published: 4, owned: 4, read: 4, readBetween: (400, 52), rating: 4,
            slug: "chateau-animaux", firstPublishedIn: 2019
        ),
        Saga(
            id: "cantos-hyperion", name: local("Les Cantos d'Hypérion", "Hyperion Cantos"),
            authors: ["Dan Simmons"],
            format: .audiobook, media: [.digital], genre: .scienceFiction,
            subgenres: ["Space opera"], minutes: [1265, 1150, 1310, 1455],
            narrators: [local("Frédéric Kneip", "Victor Bevine")],
            titles: local(
                [1: "Hypérion", 2: "La Chute d'Hypérion", 3: "Endymion", 4: "L'Éveil d'Endymion"],
                [1: "Hyperion", 2: "The Fall of Hyperion", 3: "Endymion", 4: "The Rise of Endymion"]
            ),
            published: 4, owned: 4, read: 2, readBetween: (130, 64), readingSince: 2,
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

    static func volume(_ number: Int, of saga: Saga) -> Book {
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
        // A volume still on the pile was bought along the way, as the others were
        // read: spread over the same months rather than piled on one day.
        let span = saga.readBetween.from - saga.readBetween.to
        let bought = saga.readBetween.from - span * Double(number - 1) / Double(max(1, saga.owned - 1))
        let addedAt = startedAt.map { $0.addingTimeInterval(-3 * 86400) } ?? daysAgo(bought + 1)
        return Book(
            id: "\(saga.id)-\(number)",
            title: saga.title(number),
            authors: saga.authors,
            // Folded as the server keys them: the hero's author line and its
            // "Lu par" open their pages.
            authorKeys: saga.authors.map(narratorKey),
            format: saga.format,
            media: saga.media,
            publisher: saga.publisher,
            firstPublishedIn: saga.firstPublishedIn.map { $0 + (number - 1) / 3 },
            genre: saga.genre,
            subgenres: saga.subgenres,
            pageCount: saga.pages,
            durationMinutes: saga.minutes.indices.contains(number - 1) ? saga.minutes[number - 1] : nil,
            narrators: saga.narrators,
            narratorKeys: saga.narrators.map(narratorKey),
            listeningProgress: status == .reading ? saga.listeningProgress : nil,
            language: language,
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
        rating: Double? = nil,
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
            // A book under way is a third in, as the reader last said.
            currentPage: status == .reading ? pages / 3 : nil,
            language: language,
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
        "projet-derniere-chance", local("Projet Dernière Chance", "Project Hail Mary"), ["Andy Weir"],
        publisher: local("Bragelonne", "Ballantine"), year: 2021, genre: .scienceFiction,
        subgenres: ["Hard SF", local("Premier contact", "First contact")], pages: 496, status: .read,
        days: 11, rating: 5, favorite: true,
        note: local(
            "Rocky ! Le meilleur duo de la SF depuis des années. Lu d'une traite, à relire en audio.",
            "Rocky! The best duo in sci-fi in years. Read in one sitting, listening to it next."
        ),
        synopsis: local(
            """
            Ryland Grace se réveille seul à bord d'un vaisseau, sans le moindre souvenir de \
            qui il est ni de sa mission. Peu à peu, la mémoire lui revient : il est le dernier \
            espoir de l'humanité, à des années-lumière de la Terre. Et il n'est peut-être pas \
            aussi seul qu'il le croyait.
            """,
            """
            Ryland Grace wakes up alone aboard a spaceship, with no memory of who he is or of \
            his mission. Little by little it comes back to him: he is humanity's last hope, \
            light-years from Earth. And he may not be as alone as he thought.
            """
        ),
        recommendation: BookRecommendation(
            recommenderName: local("Léa", "Emma"),
            comment: local("Tu vas adorer Rocky.", "You’re going to love Rocky.")
        )
    )

    private static let singles: [Book] = [
        featured,
        // Three French books with no English edition give their place, in
        // English, to The Way of Kings, Lessons in Chemistry and The Left Hand
        // of Darkness.
        single(
            "horde-du-contrevent", local("La Horde du Contrevent", "The Way of Kings"),
            local(["Alain Damasio"], ["Brandon Sanderson"]),
            publisher: local("Folio SF", "Tor"), year: local(2004, 2010), genre: .fantasy,
            subgenres: [local("Aventure", "Epic fantasy")],
            pages: local(736, 1007), status: .read, days: 60, rating: 5, favorite: true,
            note: local(
                "Le plus beau livre français de l'imaginaire. La typographie des pages en vent !",
                "The most breathtaking world I've read in years. Those highstorms!"
            )
        ),
        single(
            "veiller-sur-elle", local("Veiller sur elle", "Lessons in Chemistry"),
            local(["Jean-Baptiste Andrea"], ["Bonnie Garmus"]),
            publisher: local("L'Iconoclaste", "Doubleday"), year: local(2023, 2022),
            genre: .literaryFiction, pages: local(592, 400), status: .read, days: 33, rating: 4
        ),
        single(
            "shibumi", "Shibumi", ["Trevanian"], publisher: local("Gallmeister", "Crown"), year: 1979,
            genre: .thriller, subgenres: [local("Espionnage", "Espionage")], pages: 512,
            status: .read, days: 90, rating: 5, favorite: true
        ),
        single(
            "dune", "Dune", ["Frank Herbert"], publisher: local("Robert Laffont", "Ace"), year: 1965,
            genre: .scienceFiction, pages: local(832, 896), series: ("Dune", 1), status: .read,
            days: 45, rating: 4
        ),
        single(
            "messie-de-dune", local("Le Messie de Dune", "Dune Messiah"), ["Frank Herbert"],
            publisher: local("Robert Laffont", "Ace"), year: 1969, genre: .scienceFiction,
            pages: local(384, 352), series: ("Dune", 2), status: .toRead, days: 44
        ),
        single(
            "nom-du-vent", local("Le Nom du vent", "The Name of the Wind"), ["Patrick Rothfuss"],
            publisher: local("Bragelonne", "DAW"), year: 2007, genre: .fantasy,
            pages: local(864, 722), series: (kingkiller, 1), status: .read, days: 210, rating: 5,
            favorite: true
        ),
        single(
            "peur-du-sage", local("La Peur du sage", "The Wise Man’s Fear"), ["Patrick Rothfuss"],
            publisher: local("Bragelonne", "DAW"), year: 2011, genre: .fantasy,
            pages: local(720, 994), series: (kingkiller, 2), status: .reading, days: 14
        ),
        single(
            "trois-corps", local("Le Problème à trois corps", "The Three-Body Problem"), ["Liu Cixin"],
            publisher: local("Actes Sud", "Tor"), year: 2008, genre: .scienceFiction,
            pages: local(432, 400), series: (threeBody, 1), status: .read, days: 500, rating: 4
        ),
        single(
            "foret-sombre", local("La Forêt sombre", "The Dark Forest"), ["Liu Cixin"],
            publisher: local("Actes Sud", "Tor"), year: 2008, genre: .scienceFiction,
            pages: local(640, 512), series: (threeBody, 2), status: .read, days: 470, rating: 5
        ),
        single(
            "mort-immortelle", local("La Mort immortelle", "Death’s End"), ["Liu Cixin"],
            publisher: local("Actes Sud", "Tor"), year: 2010, genre: .scienceFiction,
            pages: local(816, 604), series: (threeBody, 3), status: .toRead, days: 460
        ),
        single(
            "fondation", local("Fondation", "Foundation"), ["Isaac Asimov"],
            publisher: local("Folio SF", "Del Rey"), year: 1951, genre: .scienceFiction,
            pages: local(416, 256), status: .read, days: 700, rating: 4
        ),
        single(
            "fourth-wing", "Fourth Wing", ["Rebecca Yarros"], publisher: local("Hugo Roman", "Entangled"),
            year: 2023, genre: .fantasy, subgenres: ["Romantasy"], pages: local(640, 528),
            status: .read, days: 150, rating: 4
        ),
        single(
            "sapiens", "Sapiens", ["Yuval Noah Harari"], publisher: local("Albin Michel", "Harper"),
            year: local(2015, 2014), genre: .history, pages: local(512, 464), status: .read,
            days: 260, rating: 4
        ),
        single(
            "monte-cristo", local("Le Comte de Monte-Cristo", "The Count of Monte Cristo"),
            ["Alexandre Dumas"], publisher: local("Le Livre de Poche", "Penguin Classics"), year: 1844,
            genre: .adventure, pages: local(1504, 1276), status: .toRead, days: 120
        ),
        single(
            "demain-et-demain",
            local("Demain, et demain, et demain", "Tomorrow, and Tomorrow, and Tomorrow"),
            ["Gabrielle Zevin"], publisher: local("Calmann-Lévy", "Knopf"), year: 2022,
            genre: .literaryFiction, pages: local(528, 416), status: .toRead, days: 30
        ),
        single(
            "furtifs", local("Les Furtifs", "The Left Hand of Darkness"),
            local(["Alain Damasio"], ["Ursula K. Le Guin"]), publisher: local("La Volte", "Ace"),
            year: local(2019, 1969), genre: .scienceFiction, pages: local(704, 304),
            status: .toRead, days: 70
        ),
    ] + classics + frenchNovels

    /// The science-fiction classics, old and new: the shelf is a reader's first.
    private static let classics: [Book] = [
        single(
            "1984", "1984", ["George Orwell"], publisher: local("Folio", "Signet Classics"), year: 1949,
            genre: .scienceFiction, subgenres: [local("Dystopie", "Dystopia")], pages: local(432, 328),
            status: .read, days: 8, rating: 5, favorite: true
        ),
        single(
            "meilleur-des-mondes", local("Le Meilleur des mondes", "Brave New World"), ["Aldous Huxley"],
            publisher: local("Pocket", "Harper Perennial"), year: 1932, genre: .scienceFiction,
            subgenres: [local("Dystopie", "Dystopia")], pages: 288, status: .read, days: 120, rating: 4
        ),
        single(
            "fahrenheit-451", "Fahrenheit 451", ["Ray Bradbury"],
            publisher: local("Folio SF", "Simon & Schuster"), year: 1953, genre: .scienceFiction,
            subgenres: [local("Dystopie", "Dystopia")], pages: local(224, 256), status: .read, days: 19,
            rating: 4
        ),
        single(
            "neuromancien", local("Neuromancien", "Neuromancer"), ["William Gibson"],
            publisher: local("J'ai lu", "Ace"), year: 1984, genre: .scienceFiction, subgenres: ["Cyberpunk"],
            pages: local(320, 271), status: .read, days: 340, rating: 4
        ),
        single(
            "androides",
            local("Blade Runner", "Do Androids Dream of Electric Sheep?"),
            ["Philip K. Dick"], publisher: local("J'ai lu", "Del Rey"), year: 1968, genre: .scienceFiction,
            subgenres: ["Cyberpunk"], pages: local(256, 240), status: .toRead, days: 25
        ),
        single(
            "ender", local("La Stratégie Ender", "Ender’s Game"), ["Orson Scott Card"],
            publisher: local("J'ai lu", "Tor"), year: 1985, genre: .scienceFiction,
            subgenres: [local("SF militaire", "Military SF")], pages: local(416, 324), status: .read, days: 260,
            rating: 5, favorite: true
        ),
        // Rendezvous with Rama has no French ebook to draw: Ravage stands in for it.
        single(
            "rama", local("Ravage", "Rendezvous with Rama"), local(["René Barjavel"], ["Arthur C. Clarke"]),
            publisher: local("Folio", "Del Rey"), year: local(1943, 1973), genre: .scienceFiction,
            subgenres: [local("Post-apocalyptique", "Hard SF")], pages: local(320, 256), status: .read,
            days: 400, rating: 4
        ),
        single(
            "solaris", "Solaris", ["Stanisław Lem"], publisher: local("Folio SF", "Harvest"), year: 1961,
            genre: .scienceFiction, subgenres: [local("Premier contact", "First contact")],
            pages: local(352, 204), status: .toRead, days: 75
        ),
        // Two French novels with no American ebook give their place, in English,
        // to Flowers for Algernon and Childhood's End.
        single(
            "fourmis", local("Les Fourmis", "Flowers for Algernon"), local(["Bernard Werber"], ["Daniel Keyes"]),
            publisher: local("Le Livre de Poche", "Mariner"), year: local(1991, 1966), genre: .scienceFiction,
            pages: local(320, 311), status: .read, days: 600, rating: 4
        ),
        single(
            "planete-des-singes", local("La Planète des singes", "Planet of the Apes"), ["Pierre Boulle"],
            publisher: local("Pocket", "Vintage"), year: 1963, genre: .scienceFiction,
            pages: local(192, 272), status: .read, days: 160, rating: 4
        ),
        single(
            "nuit-des-temps", local("La Nuit des temps", "Childhood’s End"),
            local(["René Barjavel"], ["Arthur C. Clarke"]), publisher: local("Pocket", "Del Rey"),
            year: local(1968, 1953), genre: .scienceFiction, pages: local(416, 224), status: .read, days: 75,
            rating: 5, favorite: true
        ),
        single(
            "seul-sur-mars", local("Seul sur Mars", "The Martian"), ["Andy Weir"],
            publisher: local("Bragelonne", "Broadway"), year: 2011, genre: .scienceFiction, subgenres: ["Hard SF"],
            pages: local(416, 387), status: .read, days: 28, rating: 5
        ),
        single(
            "silo", local("Silo", "Wool"), ["Hugh Howey"], publisher: local("Actes Sud", "Mariner"), year: 2011,
            genre: .scienceFiction, subgenres: [local("Post-apocalyptique", "Post-apocalyptic")],
            pages: local(576, 528), status: .reading, days: 6
        ),
        single(
            "guide-galactique",
            local("Le Guide du voyageur galactique", "The Hitchhiker’s Guide to the Galaxy"), ["Douglas Adams"],
            publisher: local("Folio SF", "Del Rey"), year: 1979, genre: .scienceFiction,
            subgenres: [local("Humour", "Humor")], pages: local(288, 208), status: .read, days: 220,
            rating: 5, favorite: true
        ),
        single(
            "chroniques-martiennes", local("Chroniques martiennes", "The Martian Chronicles"), ["Ray Bradbury"],
            publisher: local("Folio SF", "Simon & Schuster"), year: 1950, genre: .scienceFiction,
            pages: local(320, 256), status: .toRead, days: 160
        ),
        single(
            "station-eleven", "Station Eleven", ["Emily St. John Mandel"],
            publisher: local("Rivages", "Vintage"), year: 2014, genre: .scienceFiction,
            subgenres: [local("Post-apocalyptique", "Post-apocalyptic")], pages: local(480, 352),
            status: .read, days: 52, rating: 4
        ),
        single(
            "murderbot", local("Défaillances systèmes", "All Systems Red"), ["Martha Wells"],
            publisher: local("L'Atalante", "Tor.com"), year: 2017, genre: .scienceFiction,
            subgenres: ["Space opera"], pages: 160, series: (murderbot, 1), status: .read, days: 14, rating: 5
        ),
        single(
            "depossedes", local("Les Dépossédés", "The Dispossessed"), ["Ursula K. Le Guin"],
            publisher: local("Le Livre de Poche", "Harper Voyager"), year: 1974, genre: .scienceFiction,
            subgenres: [local("Utopie", "Utopia")], pages: local(448, 387), status: .toRead, days: 95
        ),
        single(
            "servante-ecarlate", local("La Servante écarlate", "The Handmaid’s Tale"), ["Margaret Atwood"],
            publisher: local("Robert Laffont", "Anchor"), year: 1985, genre: .scienceFiction,
            subgenres: [local("Dystopie", "Dystopia")], pages: local(544, 311), status: .read, days: 300,
            rating: 4
        ),
    ]

    /// The great French novels, in their American translations in English.
    private static let frenchNovels: [Book] = [
        single(
            "etranger", local("L'Étranger", "The Stranger"), ["Albert Camus"],
            publisher: local("Folio", "Vintage"), year: 1942, genre: .literaryFiction, pages: local(192, 123),
            status: .read, days: 33, rating: 5, favorite: true
        ),
        single(
            "peste", local("La Peste", "The Plague"), ["Albert Camus"], publisher: local("Folio", "Vintage"),
            year: 1947, genre: .literaryFiction, pages: local(352, 308), status: .toRead, days: 10
        ),
        single(
            "miserables", "Les Misérables", ["Victor Hugo"],
            publisher: local("Folio classique", "Signet Classics"), year: 1862, genre: .literaryFiction,
            subgenres: [local("Classique", "Classic")], pages: local(1664, 1463), status: .toRead, days: 40
        ),
        single(
            "madame-bovary", "Madame Bovary", ["Gustave Flaubert"],
            publisher: local("Folio classique", "Penguin Classics"), year: 1857, genre: .literaryFiction,
            subgenres: [local("Classique", "Classic")], pages: local(528, 384), status: .read, days: 140,
            rating: 4
        ),
        single(
            "rouge-et-noir", local("Le Rouge et le Noir", "The Red and the Black"), ["Stendhal"],
            publisher: local("Folio classique", "Penguin Classics"), year: 1830, genre: .literaryFiction,
            subgenres: [local("Classique", "Classic")], pages: local(752, 576), status: .read, days: 480,
            rating: 4
        ),
        single(
            "germinal", "Germinal", ["Émile Zola"], publisher: local("Le Livre de Poche", "Penguin Classics"),
            year: 1885, genre: .literaryFiction, subgenres: [local("Classique", "Classic")],
            pages: local(608, 544), status: .read, days: 36, rating: 5, favorite: true
        ),
        single(
            "petit-prince", local("Le Petit Prince", "The Little Prince"), ["Antoine de Saint-Exupéry"],
            publisher: local("Folio", "Mariner"), year: 1943, genre: .literaryFiction,
            subgenres: [local("Conte", "Fable")], pages: local(128, 96), status: .read, days: 180, rating: 5,
            favorite: true
        ),
        single(
            "bel-ami", "Bel-Ami", ["Guy de Maupassant"], publisher: local("Le Livre de Poche", "Penguin Classics"),
            year: 1885, genre: .literaryFiction, subgenres: [local("Classique", "Classic")],
            pages: local(448, 416), status: .read, days: 380, rating: 4
        ),
        single(
            "notre-dame", local("Notre-Dame de Paris", "The Hunchback of Notre-Dame"), ["Victor Hugo"],
            publisher: local("Le Livre de Poche", "Penguin Classics"), year: 1831, genre: .historicalFiction,
            pages: local(960, 940), status: .read, days: 550, rating: 4
        ),
        single(
            "trois-mousquetaires", local("Les Trois Mousquetaires", "The Three Musketeers"), ["Alexandre Dumas"],
            publisher: local("Folio classique", "Penguin Classics"), year: 1844, genre: .adventure,
            pages: local(896, 736), status: .read, days: 650, rating: 5
        ),
        single(
            "candide", "Candide", ["Voltaire"], publisher: local("Folio classique", "Penguin Classics"),
            year: 1759, genre: .literaryFiction, subgenres: [local("Conte philosophique", "Philosophical tale")],
            pages: local(192, 144), status: .read, days: 90, rating: 4
        ),
        single(
            "pere-goriot", local("Le Père Goriot", "Père Goriot"), ["Honoré de Balzac"],
            publisher: local("Le Livre de Poche", "Oxford World’s Classics"), year: 1835,
            genre: .literaryFiction, subgenres: [local("Classique", "Classic")], pages: local(416, 320),
            status: .toRead, days: 210
        ),
        single(
            "vingt-mille-lieues",
            local("Vingt mille lieues sous les mers", "Twenty Thousand Leagues Under the Sea"), ["Jules Verne"],
            publisher: local("Le Livre de Poche", "Penguin Classics"), year: 1870, genre: .adventure,
            pages: local(608, 480), status: .read, days: 720, rating: 4
        ),
        single(
            "promesse-de-l-aube", local("La Promesse de l'aube", "Promise at Dawn"), ["Romain Gary"],
            publisher: local("Folio", "New Directions"), year: 1960, genre: .literaryFiction,
            pages: local(400, 352), status: .read, days: 240, rating: 5
        ),
        single(
            "anomalie", local("L'Anomalie", "The Anomaly"), ["Hervé Le Tellier"],
            publisher: local("Gallimard", "Other Press"), year: 2020, genre: .literaryFiction,
            pages: local(336, 400), status: .read, days: 65, rating: 4
        ),
        single(
            "liaisons-dangereuses", local("Les Liaisons dangereuses", "Dangerous Liaisons"),
            ["Choderlos de Laclos"], publisher: local("Folio classique", "Penguin Classics"), year: 1782,
            genre: .literaryFiction, subgenres: [local("Classique", "Classic")], pages: local(544, 432),
            status: .toRead, days: 130
        ),
        single(
            "swann", local("Du côté de chez Swann", "Swann’s Way"), ["Marcel Proust"],
            publisher: local("Folio classique", "Penguin Classics"), year: 1913, genre: .literaryFiction,
            subgenres: [local("Classique", "Classic")], pages: local(560, 496), status: .toRead, days: 300
        ),
    ]

    private static let murderbot = local("Journal d'un AssaSynth", "The Murderbot Diaries")

    private static let kingkiller = local("Chronique du tueur de roi", "The Kingkiller Chronicle")
    private static let threeBody = local("Le Problème à trois corps", "Remembrance of Earth’s Past")

    /// Newest on the shelf first, as the server orders the Library tab.
    static var shelved: [Book] {
        books.sorted { ($0.shelvedAt ?? .distantPast) > ($1.shelvedAt ?? .distantPast) }
    }

    static func book(id: String) -> Book? {
        books.first { $0.id == id }
    }

    /// What the cover picker offers a book: the cover it is drawn with, then
    /// the other edition's when the shelf holds one, so the picker has a choice.
    static func coverChoices(id: String) -> [CoverChoice] {
        guard let current = book(id: id)?.coverURL else { return [] }
        let file = current.lastPathComponent
        let others = [covers.appending(path: "en/\(file)"), covers.appending(path: file)]
            .filter { $0.path != current.path && FileManager.default.fileExists(atPath: $0.path) }
        return [CoverChoice(source: .amazon, url: current, isCurrent: true)]
            + others.map { CoverChoice(source: .otherEdition, url: $0, isCurrent: false) }
    }
}
#endif
