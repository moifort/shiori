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
    private static func local<T>(_ french: T, _ english: T) -> T {
        isEnglish ? english : french
    }

    /// The language every book of the shelf is in.
    private static let language: BookLanguage = local(.fr, .en)

    /// The reader the captures belong to.
    static let firstName = local("Thibaut", "Alex")

    // MARK: - Covers

    private static let covers = URL(fileURLWithPath: #filePath)
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
        // A volume still on the pile was bought along the way, as the others were
        // read: spread over the same months rather than piled on one day.
        let span = saga.readBetween.from - saga.readBetween.to
        let bought = saga.readBetween.from - span * Double(number - 1) / Double(max(1, saga.owned - 1))
        let addedAt = startedAt.map { $0.addingTimeInterval(-3 * 86400) } ?? daysAgo(bought + 1)
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

    // MARK: - Library

    /// The Library tab's entry screen, drawn from the shelf as the server
    /// draws it.
    static func libraryShelves(view: ShelvesView) -> LibraryShelves {
        let inGenre = shelved.filter { book in
            (view.genre == nil || book.genre == view.genre)
                && (view.subgenre == nil || book.subgenres.contains { $0.caseInsensitiveCompare(view.subgenre ?? "") == .orderedSame })
        }
        let kept = inGenre.filter { view.format == nil || $0.format == view.format }
        var genres: [BookGenre: GenreShelf] = [:]
        for book in kept {
            guard let genre = book.genre else { continue }
            let shelf = genres[genre]
            genres[genre] = GenreShelf(
                genre: genre,
                count: (shelf?.count ?? 0) + 1,
                coverURL: shelf?.coverURL ?? book.coverURL
            )
        }
        var subgenres: [String: Int] = [:]
        if view.genre != nil {
            for book in shelved where book.genre == view.genre {
                for subgenre in book.subgenres { subgenres[subgenre, default: 0] += 1 }
            }
        }
        let keptIds = Set(kept.map(\.id))
        return LibraryShelves(
            formats: BookFormat.allCases.filter { format in inGenre.contains { $0.format == format } },
            recent: Array(kept.prefix(20)),
            toRead: Array(kept.filter { $0.status == .toRead }.prefix(20)),
            readRecently: Array(kept.filter { $0.status == .read }.prefix(20)),
            favorites: Array(kept.filter(\.favorite).prefix(20)),
            hasDropped: kept.contains { $0.status == .dropped },
            genres: genres.values.sorted { ($0.count, $1.genre.label) > ($1.count, $0.genre.label) },
            subgenres: subgenres.sorted { ($0.value, $1.key) > ($1.value, $0.key) }.map(\.key),
            series: sagas.map(followed)
                .filter { series in series.volumes.contains { keptIds.contains($0.id) } }
                .sorted { ($0.shelvedAt ?? .distantPast) > ($1.shelvedAt ?? .distantPast) },
            authors: authorsPage(limit: 12, after: nil, order: .recent).items
                .filter { author in author.books.contains { keptIds.contains($0.id) } }
        )
    }

    /// The series of "Coups de cœur": the hearted sagas holding a book of
    /// the view, the one shelved last first.
    static func lovedSeries(view: ShelvesView) -> [FollowedSeries] {
        lovedSagas(holding: Set(shelved.filter { book in
            (view.format == nil || book.format == view.format) && (view.genre == nil || book.genre == view.genre)
        }.map(\.id)))
    }

    /// The hearted sagas holding one of the books given, the one shelved
    /// last first.
    private static func lovedSagas(holding ids: Set<String>) -> [FollowedSeries] {
        sagas.map(followed)
            .filter { series in series.opinion?.favorite == true && series.volumes.contains { ids.contains($0.id) } }
            .sorted { ($0.shelvedAt ?? .distantPast) > ($1.shelvedAt ?? .distantPast) }
    }

    /// One page of a shelf of the Library tab, as the server pages it.
    static func shelfPage(_ query: ShelfQuery, limit: Int, after: String?) -> LibraryPageResult {
        let view = query.view
        let lovedVolumes = query.excludeLovedSeries
            ? Set(lovedSagas(holding: Set(shelved.map(\.id))).flatMap { $0.volumes.map(\.id) })
            : []
        let matching = shelved.filter { book in
            (view.format == nil || book.format == view.format)
                && (view.genre == nil || book.genre == view.genre)
                && (query.serverStatus == nil || book.status == query.serverStatus)
                && (!query.favorite || book.favorite)
                && !lovedVolumes.contains(book.id)
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
                        language: language,
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
                    language: language,
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
            language: language,
            state: state,
            genre: saga.genre,
            ownedCount: volumes.count,
            shelvedAt: volumes.compactMap(\.shelvedAt).max(),
            volumes: volumes,
            strip: SeriesStripItem.strip(
                owned: volumes,
                spine: spine,
                currentYear: calendar.component(.year, from: .now),
                language: language
            ),
            isCatalogued: true,
            opinion: SeriesOpinion(seriesId: saga.id, rating: saga.rating, favorite: saga.favorite),
            announced: sagaReleases(seriesId: saga.id).next
        )
    }

    static func seriesPage(limit: Int, after: String?, mode: LibraryMode, state: SeriesState?)
        -> CursorPage<FollowedSeries>
    {
        let all = sagas.map(followed)
            .filter { (mode != .favorites || $0.opinion?.favorite == true) && (state == nil || $0.state == state) }
            .sorted { ($0.shelvedAt ?? .distantPast) > ($1.shelvedAt ?? .distantPast) }
        return CursorPage(all, limit: limit, after: after, cursor: \.id)
    }

    // MARK: - Authors

    /// The Authors shelf, derived from the books as the server derives it: one
    /// row per author, their books newest shelved first.
    static func authorsPage(limit: Int, after: String?, order: AuthorListOrder) -> CursorPage<FollowedAuthor> {
        let names = Array(Set(books.flatMap(\.authors)))
        let authors = names.map { name -> FollowedAuthor in
            let theirs = shelved.filter { $0.authors.contains(name) }
            let ratings = theirs.compactMap(\.shownRating)
            let surname = name.split(separator: " ").last.map(String.init) ?? name
            return FollowedAuthor(
                key: name.lowercased(),
                name: name,
                indexLetter: String(surname.prefix(1)).uppercased(),
                // As Wikipedia shows them, where `screenshots/covers` holds one.
                portraitURL: cover("portrait-" + name.lowercased().replacingOccurrences(of: " ", with: "-")),
                bookCount: theirs.count,
                seriesCount: Set(theirs.compactMap(\.series?.id)).count,
                favoriteCount: theirs.filter(\.favorite).count,
                averageRating: ratings.isEmpty ? nil : Double(ratings.reduce(0, +)) / Double(ratings.count),
                shelvedAt: theirs.compactMap(\.shelvedAt).max(),
                books: theirs
            )
        }
        let sorted = switch order {
        case .recent: authors.sorted { ($0.shelvedAt ?? .distantPast) > ($1.shelvedAt ?? .distantPast) }
        case .name: authors.sorted { ($0.indexLetter, $0.name) < ($1.indexLetter, $1.name) }
        case .loved: authors.sorted { ($0.favoriteCount, $0.bookCount) > ($1.favoriteCount, $1.bookCount) }
        }
        return CursorPage(sorted, limit: limit, after: after, cursor: \.id)
    }

    /// An author's page, drawn from the shelf: their sagas and their other
    /// books, and one of each they do not hold.
    static func authorPage(key: String) -> AuthorPage? {
        guard let author = authorsPage(limit: 200, after: nil, order: .recent).items.first(where: { $0.key == key })
        else { return nil }
        let sagas = sagas.filter { $0.authors.contains(author.name) }.map(followed)
        return AuthorPage(
            author: author,
            readCount: author.books.filter { $0.status == .read }.count,
            nationality: local("Américain", "American"),
            birthYear: 1972,
            deathYear: nil,
            biography: local(
                "Auteur américain, dessinateur de bandes dessinées avant de publier en ligne une série de science-fiction devenue un phénomène, traduite dans le monde entier et adaptée en livre audio.",
                "American author, a cartoonist before he published online a science-fiction series that became a phenomenon, translated worldwide and adapted as an audiobook."
            ),
            sagas: sagas,
            sagasNotHeld: [],
            books: author.books.filter { $0.series == nil },
            booksNotHeld: [AuthorWork(title: local("Le Jour des morts", "The Day of the Dead"), publishedIn: 2015, coverURL: nil)]
        )
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
            // With their authors' keys, as the screen's query brings them:
            // the hero's author line opens the author's page.
            owned: books.filter { $0.series?.id == saga.id }.map { book in
                var book = book
                book.authorKeys = book.authors.map { $0.lowercased().replacingOccurrences(of: " ", with: "-") }
                return book
            }
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
        let firstYear = read.compactMap(finishedYear).min() ?? year
        let pile = books.filter { $0.status == .toRead }
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
            toRead: Array(pile.sorted { ($0.addedAt ?? .distantPast) > ($1.addedAt ?? .distantPast) }.prefix(12)),
            lastFinished: read.max { ($0.finishedAt ?? .distantPast) < ($1.finishedAt ?? .distantPast) },
            toReadCount: pile.count,
            readCount: read.count,
            pagesRead: read.compactMap(\.pageCount).reduce(0, +),
            hoursListened: read.compactMap(\.durationMinutes).reduce(0, +) / 60,
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
                    favorite: saga?.favorite ?? false,
                    coverURL: series.volumes.last?.coverURL
                )
            },
            favoriteCount: books.filter(\.favorite).count + sagas.filter(\.favorite).count,
            hasAudiobooks: books.contains { $0.format == .audiobook },
            hasPrintedBooks: true,
            libraryIsEmpty: false
        )
    }

    /// The detailed statistics, counted off the same shelf.
    static var genreInsights: GenreInsights {
        let read = books.filter { $0.status == .read }
        let byGenre = Dictionary(grouping: read.filter { $0.genre != nil }) { $0.genre! }
        let shares = byGenre.map { GenreInsights.Share(genre: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
        let formats = Dictionary(grouping: read, by: \.format).map { format, books in
            let top = Dictionary(grouping: books.compactMap(\.genre), by: { $0 })
                .max { $0.value.count < $1.value.count }?.key
            return GenreInsights.FormatShare(format: format, count: books.count, topGenre: top)
        }.sorted { $0.count > $1.count }
        // A taste: a genre, or one of its subgenres, and the stars its books got.
        var groups: [String: (genre: BookGenre, subgenre: String?, ratings: [Double], count: Int)] = [:]
        for book in read {
            guard let genre = book.genre else { continue }
            for subgenre in [nil] + book.subgenres.prefix(1).map(Optional.some) {
                let key = "\(genre.rawValue)~\(subgenre ?? "")"
                var group = groups[key] ?? (genre, subgenre, [], 0)
                group.count += 1
                if let stars = book.shownRating { group.ratings.append(stars) }
                groups[key] = group
            }
        }
        let tastes = groups.values
            .filter { !$0.ratings.isEmpty && $0.count >= 2 }
            .map {
                GenreInsights.Taste(
                    genre: $0.genre, subgenre: $0.subgenre, readCount: $0.count,
                    averageRating: Double($0.ratings.reduce(0, +)) / Double($0.ratings.count)
                )
            }
            .sorted { $0.readCount > $1.readCount }
        let rated = read.compactMap(\.shownRating)
        let paged = Dictionary(grouping: read.filter { $0.pageCount != nil && $0.genre != nil }) { $0.genre! }
            .filter { $0.value.count >= 2 }
            .mapValues { $0.compactMap(\.pageCount).reduce(0, +) / $0.count }
        let days = Dictionary(grouping: read.filter { $0.genre != nil && $0.startedAt != nil }) { $0.genre! }
            .filter { $0.value.count >= 2 }
            .mapValues { books in
                books.map { ($0.finishedAt!.timeIntervalSince($0.startedAt!) / 86400).rounded(.up) }
                    .reduce(0, +) / Double(books.count)
            }
        let pile = books.filter { $0.status == .toRead }
        return GenreInsights(
            readCount: read.count,
            shares: shares,
            formats: formats,
            tastes: Array(tastes.prefix(7)),
            averageRating: rated.isEmpty ? nil : Double(rated.reduce(0, +)) / Double(rated.count),
            gem: tastes.filter { $0.readCount >= 3 }.max { $0.averageRating < $1.averageRating },
            longest: paged.max { $0.value < $1.value }.map { .init(genre: $0.key, averagePages: $0.value) },
            fastest: days.min { $0.value < $1.value }.map { .init(genre: $0.key, averageDays: max(1, Int($0.value))) },
            mostDropped: nil,
            unexplored: BookGenre.allCases
                .filter { $0 != .other && byGenre[$0] == nil }
                .map { genre in .init(genre: genre, pileCount: pile.filter { $0.genre == genre }.count) }
                .sorted { $0.pileCount > $1.pileCount }
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
    static var monthlyDiscoveries: MonthlyDiscoveries {
        MonthlyDiscoveries(
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
