import Foundation

enum AuthorsAPI {
    /// One page of the authors the reader holds books of, the ones they love
    /// first, or only those with a heart.
    static func myAuthorsPage(
        limit: Int,
        offset: Int,
        mode: LibraryMode = .all
    ) async throws -> (items: [FollowedAuthor], hasMore: Bool) {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.MyAuthorsPageQuery(
                limit: .some(Int32(limit)),
                offset: .some(Int32(offset)),
                favorite: mode == .favorites ? .some(true) : .none
            )
        )
        return (
            items: data.myAuthorsPage.items.map { item in
                FollowedAuthor(
                    key: item.key,
                    name: item.name,
                    bookCount: item.bookCount,
                    seriesCount: item.seriesCount,
                    favoriteCount: item.favoriteCount,
                    averageRating: item.averageRating,
                    books: item.books.map(\.fragments.followedVolume.asBook),
                    saga: item.saga.map {
                        AuthorSaga(
                            series: FollowedSeries(row: $0.series.fragments.followedSeriesRow),
                            readCount: $0.readCount,
                            totalCount: $0.totalCount
                        )
                    }
                )
            },
            hasMore: data.myAuthorsPage.hasMore
        )
    }
}
