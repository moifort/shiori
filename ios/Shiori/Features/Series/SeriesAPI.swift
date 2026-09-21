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

    /// One page of the sagas the reader follows, in the same order.
    static func mySeriesPage(limit: Int, offset: Int) async throws -> (items: [FollowedSeries], hasMore: Bool) {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.MySeriesPageQuery(limit: .some(limit), offset: .some(offset))
        )
        return (
            items: data.mySeriesPage.items.map { FollowedSeries(row: $0.fragments.followedSeriesRow) },
            hasMore: data.mySeriesPage.hasMore
        )
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
            ownedCount: followed.ownedCount,
            opinion: followed.opinion?.fragments.seriesOpinionFields.asOpinion
        )
    }
}
