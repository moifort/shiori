import Foundation
import ShioriGraphQL

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
            query: MySeriesQuery()
        )
        return data.mySeries.map { followed in
            FollowedSeries(
                series: BookSeries(
                    id: followed.series.id,
                    name: followed.series.name,
                    author: followed.series.author
                ),
                state: followed.state.asDomain,
                ownedCount: followed.ownedCount
            )
        }
    }
}
