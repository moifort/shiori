import Foundation

enum SeriesAPI {
    /// How long the app waits for a saga's catalogue. A saga nobody has
    /// described yet — one an Audible import named — is catalogued by the server
    /// on this first opening, with one web-grounded model call that a cold
    /// function can stretch well past the session's 60 s; every later opening
    /// reads the stored catalogue and answers at once.
    private static let firstOpeningTimeout: TimeInterval = 120

    /// The full catalogue of one saga — owned volumes and unowned alike. Nil
    /// only when the server could not build it: the catalogue call failed, or
    /// the model found no volumes. The next opening tries again.
    static func series(id: String) async throws -> BookSeries? {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.SeriesQuery(id: id),
            requestTimeout: firstOpeningTimeout
        )
        guard let series = data.series else { return nil }
        return BookSeries(
            id: series.id,
            name: series.name,
            author: series.author,
            description: series.description,
            spine: series.spine.map { $0.fragments.volumeEntry.asVolume },
            relatedWorks: series.relatedWorks.map { $0.fragments.volumeEntry.asVolume }
        )
    }

    /// Every saga the reader owns a volume of, alphabetically.
    static func mySeries() async throws -> [FollowedSeries] {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.MySeriesQuery()
        )
        return data.mySeries.map { FollowedSeries(row: $0.fragments.followedSeriesRow) }
    }

    /// One page of the sagas the reader follows, arranged and narrowed as the
    /// Library tab is: sectioned by state or by genre, the hearted sagas only,
    /// or the sagas in one state.
    static func mySeriesPage(
        limit: Int,
        offset: Int,
        mode: LibraryMode = .all,
        state: SeriesState? = nil
    ) async throws -> (items: [FollowedSeries], hasMore: Bool) {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.MySeriesPageQuery(
                limit: .some(Int32(limit)),
                offset: .some(Int32(offset)),
                arrangement: .some(.case(mode == .genre ? .byGenre : .byStatus)),
                favorite: mode == .favorites ? .some(true) : .none,
                state: state.map { .some(.case(graphQLState($0))) } ?? .none
            )
        )
        let currentYear = Calendar.current.component(.year, from: .now)
        return (
            items: data.mySeriesPage.items.map { item in
                var followed = FollowedSeries(row: item.fragments.followedSeriesRow)
                followed.volumes = item.volumes.map { $0.fragments.followedVolume.asBook }
                followed.strip = SeriesStripItem.strip(
                    owned: followed.volumes,
                    spine: item.catalogue?.spine.map { $0.fragments.volumeEntry.asVolume } ?? [],
                    currentYear: currentYear
                )
                return followed
            },
            hasMore: data.mySeriesPage.hasMore
        )
    }

    private static func graphQLState(_ state: SeriesState) -> ShioriGraphQL.SeriesState {
        switch state {
        case .notStarted: .notStarted
        case .inProgress: .inProgress
        case .complete: .complete
        }
    }

    /// Removes the saga from the library: every volume the reader holds, and
    /// their rating and heart for it. Answers how many books went.
    @discardableResult
    static func delete(seriesId: String) async throws -> Int {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.DeleteSeriesMutation(seriesId: seriesId)
        )
        return data.deleteSeries
    }

    /// What the reader makes of one saga. Nil until they say something about it:
    /// an opinion with neither a rating nor a heart is not stored.
    static func opinion(seriesId: String) async throws -> SeriesOpinion? {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.SeriesOpinionQuery(seriesId: seriesId)
        )
        return data.seriesOpinion?.fragments.seriesOpinionFields.asOpinion
    }

    /// Rate the saga itself. Leaves every volume rating alone — the two say
    /// different things about different objects.
    static func rate(seriesId: String, stars: Int) async throws -> SeriesOpinion {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.RateSeriesMutation(seriesId: seriesId, rating: stars)
        )
        return data.rateSeries.fragments.seriesOpinionFields.asOpinion
    }

    static func removeRating(seriesId: String) async throws -> SeriesOpinion {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.RemoveSeriesRatingMutation(seriesId: seriesId)
        )
        return data.removeSeriesRating.fragments.seriesOpinionFields.asOpinion
    }

    static func setFavorite(seriesId: String, favorite: Bool) async throws -> SeriesOpinion {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.SetSeriesFavoriteMutation(seriesId: seriesId, favorite: favorite)
        )
        return data.setSeriesFavorite.fragments.seriesOpinionFields.asOpinion
    }
}

private extension FollowedSeries {
    init(row followed: ShioriGraphQL.FollowedSeriesRow) {
        self.init(
            seriesId: followed.id,
            name: followed.name,
            author: followed.author,
            language: followed.language?.asDomain,
            state: followed.state?.asDomain,
            genre: followed.genre?.asDomain,
            ownedCount: followed.ownedCount,
            opinion: followed.opinion?.fragments.seriesOpinionFields.asOpinion
        )
    }
}

private extension ShioriGraphQL.FollowedVolume {
    /// Only what a cover in the strip draws: the image, the status pinned on
    /// it, and the title the placeholder is lettered from.
    var asBook: Book {
        Book(
            id: id,
            title: title,
            authors: [],
            format: format.asDomain,
            series: series.map {
                SeriesMembership(id: "", name: "", volume: $0.volume, kind: $0.kind.asDomain)
            },
            coverURL: coverUrl.flatMap(URL.init(string:)),
            status: status.asDomain
        )
    }
}
