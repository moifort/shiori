import Foundation

enum HomeAPI {
    /// Counted in the device time zone, so a book finished on New Year's Eve lands
    /// on the year the reader lived it in.
    static func dashboard() async throws -> Dashboard {
        #if DEBUG
        if Showcase.isOn {
            return Showcase.dashboard
        }
        #endif
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.DashboardQuery(timeZone: TimeZone.current.identifier)
        )
        return Dashboard(fields: data.dashboard.fragments.dashboardFields)
    }

    /// The top of the home in one request — the dashboard and the month's
    /// discoveries as they stand — so the server reads the library once for
    /// both.
    static func opening() async throws -> HomeOpening {
        #if DEBUG
        if Showcase.isOn {
            return HomeOpening(dashboard: Showcase.dashboard, discoveries: Showcase.monthlyDiscoveries)
        }
        #endif
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.HomeOpeningQuery(timeZone: TimeZone.current.identifier)
        )
        return HomeOpening(
            dashboard: Dashboard(fields: data.dashboard.fragments.dashboardFields),
            discoveries: MonthlyDiscoveries(fields: data.monthlyDiscoveries.fragments.monthlyDiscoveriesFields)
        )
    }

    /// What the home's releases are drawn from, in one request: Découvrir's
    /// rows and the editions awaited, in both formats.
    static func releaseSources() async throws -> HomeReleaseSources {
        #if DEBUG
        if Showcase.isOn {
            return HomeReleaseSources(
                books: Showcase.discovery(format: .book),
                audiobooks: Showcase.discovery(format: .audiobook),
                awaited: []
            )
        }
        #endif
        let data = try await GraphQLHelpers.fetch(GraphQLClient.shared.apollo, query: ShioriGraphQL.HomeReleasesQuery())
        return HomeReleaseSources(
            books: DiscoveryPage(fields: data.books.fragments.discoveryFields),
            audiobooks: DiscoveryPage(fields: data.audiobooks.fragments.discoveryFields),
            awaited: data.awaitedAudiobooks.map { AwaitedEdition(fields: $0.fragments.awaitedEditionFields) }
                + data.awaitedBooks.map { AwaitedEdition(fields: $0.fragments.awaitedEditionFields) }
        )
    }
}

extension Dashboard {
    init(fields dashboard: ShioriGraphQL.DashboardFields) {
        self.init(
            currentYear: dashboard.currentYear,
            booksPerYear: dashboard.booksPerYear.map { .init(year: $0.year, count: $0.count) },
            pagesPerMonth: dashboard.pagesPerMonth.map { .init(month: $0.month, pages: $0.pages) },
            hoursPerMonth: dashboard.hoursPerMonth.map { .init(month: $0.month, hours: $0.hours) },
            reading: dashboard.reading.map { $0.fragments.dashboardBookCard.asBook(status: .reading) },
            toRead: dashboard.toRead.map { $0.fragments.dashboardBookCard.asBook(status: .toRead) },
            lastFinished: dashboard.lastFinished?.fragments.dashboardBookCard.asBook(status: .read),
            toReadCount: dashboard.toReadCount,
            readCount: dashboard.readCount,
            pagesRead: dashboard.pagesRead,
            hoursListened: dashboard.hoursListened,
            genres: dashboard.genres.map { .init(genre: $0.genre?.asDomain, count: $0.count) },
            series: dashboard.series.map {
                .init(
                    id: $0.id,
                    name: $0.name,
                    isAudio: $0.audio,
                    language: $0.language?.asDomain,
                    readCount: $0.readCount,
                    totalCount: $0.totalCount,
                    rating: $0.rating.map { ($0 * 2).rounded() / 2 },
                    favorite: $0.favorite,
                    coverURL: $0.coverUrl.flatMap(URL.init(string:))
                )
            },
            favoriteCount: dashboard.favoriteCount,
            hasAudiobooks: dashboard.hasAudiobooks,
            hasPrintedBooks: dashboard.hasPrintedBooks,
            libraryIsEmpty: dashboard.libraryIsEmpty
        )
    }
}

extension HomeAPI {
    static func genreInsights() async throws -> GenreInsights {
        #if DEBUG
        if Showcase.isOn {
            return Showcase.genreInsights
        }
        #endif
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.GenreInsightsQuery()
        )
        let insights = data.genreInsights
        return GenreInsights(
            readCount: insights.readCount,
            shares: insights.shares.map { .init(genre: $0.genre.asDomain, count: $0.count) },
            formats: insights.formats.map {
                .init(format: $0.format.asDomain, count: $0.count, topGenre: $0.topGenre?.asDomain)
            },
            tastes: insights.tasteMap.map { $0.fragments.tastePlace.asTaste },
            averageRating: insights.averageRating,
            gem: insights.gem?.fragments.tastePlace.asTaste,
            longest: insights.longest.map { .init(genre: $0.genre.asDomain, averagePages: $0.averagePages) },
            fastest: insights.fastest.map { .init(genre: $0.genre.asDomain, averageDays: $0.averageDays) },
            mostDropped: insights.mostDropped.map {
                .init(genre: $0.genre.asDomain, droppedCount: $0.droppedCount, startedCount: $0.startedCount)
            },
            unexplored: insights.unexplored.map { .init(genre: $0.genre.asDomain, pileCount: $0.pileCount) }
        )
    }
}

private extension ShioriGraphQL.TastePlace {
    var asTaste: GenreInsights.Taste {
        .init(genre: genre.asDomain, subgenre: subgenre, readCount: readCount, averageRating: averageRating)
    }
}

private extension ShioriGraphQL.DashboardBookCard {
    /// The shelf a card comes from is its status: the server only puts reading
    /// books under "reading", and so on.
    func asBook(status: ReadingStatus) -> Book {
        Book(
            id: id,
            title: title,
            authors: authors,
            format: format.asDomain,
            pageCount: pageCount,
            currentPage: currentPage,
            durationMinutes: durationMinutes,
            listeningProgress: listeningProgress.map { Int($0) },
            series: series.map {
                SeriesMembership(id: $0.id, name: $0.name, volume: $0.volume, kind: $0.kind.asDomain)
            },
            coverURL: coverUrl.flatMap(URL.init(string:)),
            status: status,
            rating: rating,
            addedAt: addedAt.flatMap(GraphQLHelpers.parseISO8601),
            startedAt: startedAt.flatMap(GraphQLHelpers.parseISO8601),
            finishedAt: finishedAt.flatMap(GraphQLHelpers.parseISO8601)
        )
    }
}
