import Foundation

enum SeriesAPI {
    /// The full catalogue of one saga — owned volumes and unowned alike. Nil
    /// when nobody has catalogued it yet, which happens for a book added by hand
    /// or when the catalogue call failed on the scan that first met the saga.
    static func series(id: String) async throws -> BookSeries? {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.SeriesQuery(id: id)
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
        return data.mySeries.map { followed in
            FollowedSeries(
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
