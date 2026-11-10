#if DEBUG
import Foundation

/// What the showcase answers each screen with: the library, the sagas, the
/// authors and narrators, Découvrir and the dashboard, all drawn from the
/// shelf in Showcase.swift. Debug-only, as the rest of the showcase.
extension Showcase {
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
            recent: Array(kept.filter { $0.status != .dropped }.prefix(20)),
            toRead: Array(kept.filter { $0.status == .toRead }.prefix(20)),
            readRecently: Array(kept.filter { $0.status == .read }.prefix(20)),
            favorites: Array(kept.filter { $0.status != .dropped && isLoved($0) }.prefix(20)),
            genres: genres.values.sorted { ($0.count, $1.genre.label) > ($1.count, $0.genre.label) },
            subgenres: subgenres.sorted { ($0.value, $1.key) > ($1.value, $0.key) }.map(\.key),
            series: sagas.map(followed)
                .filter { series in series.volumes.contains { keptIds.contains($0.id) } }
                .sorted { ($0.shelvedAt ?? .distantPast) > ($1.shelvedAt ?? .distantPast) },
            authors: authorsPage(limit: 12, after: nil, order: .recent).items
                .filter { author in author.books.contains { keptIds.contains($0.id) } },
            narrators: kept.filter { $0.format == .audiobook }
                .flatMap(\.narrators)
                .reduce(into: [String]()) { names, name in if !names.contains(name) { names.append(name) } }
                .map { NarratorRow(key: narratorKey($0), name: $0) }
        )
    }

    /// The pile in sections, cut as the server cuts it: the history judges,
    /// the view narrows what is offered. No award winner, the showcase keeping
    /// no palmarès.
    static func pile(view: ShelvesView) -> Pile {
        let inGenre = shelved.filter { view.genre == nil || $0.genre == view.genre }
        let offered = inGenre.filter { view.format == nil || $0.format == view.format }
        let pile = offered.filter { $0.status == .toRead }
        let read = shelved.filter { $0.status == .read }
        let liked = shelved.filter { $0.favorite || ($0.rating ?? 0) >= 4 }
        let readSagas = Set(read.compactMap { $0.series?.name })
        var firstOfSaga: [String: Book] = [:]
        for book in pile {
            guard let series = book.series, readSagas.contains(series.name) else { continue }
            if (series.volume ?? .max) < (firstOfSaga[series.name]?.series?.volume ?? .max) || firstOfSaga[series.name] == nil {
                firstOfSaga[series.name] = book
            }
        }
        let readAuthors = Set(read.flatMap(\.authors))
        let likedAuthors = Set(liked.flatMap(\.authors))
        let likedNarrators = Set(liked.flatMap(\.narrators))
        let sections: [(PileSectionKind, [Book])] = [
            (.toFinish, offered.filter { $0.status == .reading }.reversed()),
            (.nextVolume, pile.filter { book in firstOfSaga.values.contains { $0.id == book.id } }),
            (.recommended, pile.filter { $0.recommendation?.recommenderName != nil }),
            (.favoriteAuthors, pile.filter { $0.authors.contains(where: likedAuthors.contains) }),
            (.favoriteNarrators, pile.filter { $0.narrators.contains(where: likedNarrators.contains) }),
            (.newAuthors, pile.filter { !$0.authors.isEmpty && !$0.authors.contains(where: readAuthors.contains) }),
        ]
        return Pile(
            formats: BookFormat.allCases.filter { format in
                inGenre.contains { $0.format == format && ($0.status == .toRead || $0.status == .reading) }
            },
            genres: BookGenre.alphabetical.filter { genre in
                shelved.contains {
                    $0.genre == genre && (view.format == nil || $0.format == view.format)
                        && ($0.status == .toRead || $0.status == .reading)
                }
            },
            sections: sections.compactMap { kind, books in
                books.isEmpty ? nil : PileSection(kind: kind, picks: books.prefix(15).map { PilePick(book: $0) })
            }
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

    /// Whether a book sits among "Coups de cœur", as the server judges it:
    /// hearted, four and a half stars or more, or unrated in a saga hearted
    /// or rated four and a half stars or more.
    static func isLoved(_ book: Book) -> Bool {
        if book.favorite { return true }
        if let rating = book.rating { return rating >= 4.5 }
        return lovedSagaVolumeIds.contains(book.id)
    }

    private static let lovedSagaVolumeIds = Set(
        sagas.map(followed)
            .filter { $0.opinion?.favorite == true || ($0.opinion?.rating ?? 0) >= 4.5 }
            .flatMap { $0.volumes.map(\.id) }
    )

    /// One page of a shelf of the Library tab, as the server pages it.
    static func shelfPage(_ query: ShelfQuery, limit: Int, after: String?) -> LibraryPageResult {
        let view = query.view
        let matching = shelved.filter { book in
            (view.format == nil || book.format == view.format)
                && (view.genre == nil || book.genre == view.genre)
                // A book given up on is listed in "Abandonnés" alone.
                && (query.serverStatus.map { book.status == $0 } ?? (book.status != .dropped))
                && (!query.favorite || isLoved(book))
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

    /// The authors the reader hearted on their pages: all that "Préférés" lists.
    static let heartedAuthors: Set<String> = ["Matt Dinniman", "Patrick Rothfuss", "Andy Weir"]

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
                books: theirs,
                favorite: heartedAuthors.contains(name),
                surname: surname
            )
        }
        let sorted = switch order {
        case .recent: authors.sorted { ($0.shelvedAt ?? .distantPast) > ($1.shelvedAt ?? .distantPast) }
        case .name: authors.sorted { ($0.indexLetter, $0.name) < ($1.indexLetter, $1.name) }
        case .loved: authors.filter(\.favorite).sorted { ($0.favoriteCount, $0.bookCount) > ($1.favoriteCount, $1.bookCount) }
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

    /// A narrator's name folded roughly as the server folds it.
    static func narratorKey(_ name: String) -> String {
        name.folding(options: .diacriticInsensitive, locale: nil).lowercased().replacingOccurrences(of: " ", with: "-")
    }

    /// The Library's narrators list, drawn from the shelf's recordings.
    static func narratorsPage(limit: Int, after: String?, order: AuthorListOrder) -> CursorPage<FollowedNarrator> {
        let heard = shelved.filter { $0.format == .audiobook }
        let names = Array(Set(heard.flatMap(\.narrators)))
        let narrators = names.map { name -> FollowedNarrator in
            let theirs = heard.filter { $0.narrators.contains(name) }
            let surname = name.split(separator: " ").last.map(String.init) ?? name
            return FollowedNarrator(
                key: narratorKey(name),
                name: name,
                indexLetter: String(surname.folding(options: .diacriticInsensitive, locale: nil).prefix(1)).uppercased(),
                shelvedAt: theirs.compactMap(\.shelvedAt).max(),
                books: theirs,
                // The reader hearted the voices of the recordings they hearted.
                favorite: theirs.contains(where: \.favorite),
                surname: surname
            )
        }
        let sorted = switch order {
        case .recent: narrators.sorted { ($0.shelvedAt ?? .distantPast) > ($1.shelvedAt ?? .distantPast) }
        case .name: narrators.sorted { ($0.indexLetter, $0.name) < ($1.indexLetter, $1.name) }
        case .loved: narrators.filter(\.favorite).sorted { $0.books.count > $1.books.count }
        }
        return CursorPage(sorted, limit: limit, after: after, cursor: \.id)
    }

    /// A narrator's page, drawn from the shelf's recordings in their voice.
    static func narratorPage(key: String) -> NarratorPage? {
        let fold = narratorKey
        let heard = books.filter { $0.format == .audiobook && $0.narrators.contains { fold($0) == key } }
        guard let name = heard.first?.narrators.first(where: { fold($0) == key }) else { return nil }
        let narrated = sagas.filter { $0.isAudio && $0.narrators.contains(name) }
        let rated = heard.compactMap(\.rating)
        return NarratorPage(
            key: key,
            name: name,
            portraitURL: nil,
            favorite: true,
            bookCount: heard.count,
            readCount: heard.filter { $0.status == .read }.count,
            seriesCount: narrated.count,
            averageRating: rated.isEmpty ? nil : Double(rated.reduce(0, +)) / Double(rated.count),
            sagas: narrated.map(followed),
            books: heard.filter { $0.series == nil },
            nationality: local("Français", "French"),
            birthYear: 1963,
            biography: local(
                "Comédien français, formé au théâtre, il prête sa voix au doublage et aux livres audio depuis les années 1990. Ses lectures de science-fiction, d'Hypérion à Dune, lui ont valu plusieurs prix du livre audio.",
                "French actor trained on stage, he has voiced dubbing and audiobooks since the 1990s. His science fiction readings, from Hyperion to Dune, won him several audiobook awards."
            )
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
}
#endif
