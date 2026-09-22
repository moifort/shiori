import Foundation

enum HomeAPI {
    /// Counted in the device time zone, so a book finished on New Year's Eve lands
    /// on the year the reader lived it in.
    static func dashboard() async throws -> Dashboard {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.DashboardQuery(timeZone: TimeZone.current.identifier)
        )
        let dashboard = data.dashboard
        return Dashboard(
            currentYear: dashboard.currentYear,
            booksPerYear: dashboard.booksPerYear.map { .init(year: $0.year, count: $0.count) },
            pagesPerMonth: dashboard.pagesPerMonth.map { .init(month: $0.month, pages: $0.pages) },
            hoursPerMonth: dashboard.hoursPerMonth.map { .init(month: $0.month, hours: $0.hours) },
            reading: dashboard.reading.map { $0.fragments.dashboardBookCard.asBook(status: .reading) },
            suggestions: dashboard.suggestions.map { $0.fragments.dashboardBookCard.asBook(status: .toRead) },
            lastFinished: dashboard.lastFinished?.fragments.dashboardBookCard.asBook(status: .read),
            pagesPerDay: .init(current: dashboard.pagesPerDay.current, previous: dashboard.pagesPerDay.previous),
            daysToFinish: .init(current: dashboard.daysToFinish.current, previous: dashboard.daysToFinish.previous),
            toReadCount: dashboard.toReadCount,
            monthsToClearPile: dashboard.monthsToClearPile,
            averageRating: dashboard.averageRating,
            ratedCount: dashboard.ratedCount,
            genres: dashboard.genres.map { .init(genre: $0.genre?.asDomain, count: $0.count) },
            series: dashboard.series.map {
                .init(id: $0.id, name: $0.name, readCount: $0.readCount, totalCount: $0.totalCount)
            },
            favoriteCount: dashboard.favoriteCount,
            droppedCount: dashboard.droppedCount,
            hasAudiobooks: dashboard.hasAudiobooks,
            hasPrintedBooks: dashboard.hasPrintedBooks,
            libraryIsEmpty: dashboard.libraryIsEmpty
        )
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
            listeningProgress: listeningProgress.map { Int($0) },
            coverURL: coverUrl.flatMap(URL.init(string:)),
            status: status,
            rating: rating,
            startedAt: startedAt.flatMap(GraphQLHelpers.parseISO8601),
            finishedAt: finishedAt.flatMap(GraphQLHelpers.parseISO8601)
        )
    }
}
