import Foundation

enum NewsAPI {
    /// One page of what the friends did, newest first.
    static func feed(after: String?, limit: Int) async throws -> CursorPage<FeedEvent> {
        #if DEBUG
        if Showcase.isOn { return CursorPage(items: [], hasMore: false, endCursor: nil) }
        #endif
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.NewsFeedQuery(limit: Int32(limit), after: GraphQLHelpers.graphQLNullable(after))
        )
        let page = data.newsFeed
        let events = page.events.compactMap { row -> FeedEvent? in
            guard let kind = row.kind.value.flatMap({ FeedEventKind(rawValue: $0.rawValue.lowercased()) }),
                let at = GraphQLHelpers.parseISO8601(row.at)
            else { return nil }
            return FeedEvent(
                id: row.id,
                kind: kind,
                at: at,
                friendId: row.friendId,
                friendName: row.friendFirstName ?? "",
                bookId: row.bookId,
                title: row.title,
                authors: row.authors,
                format: row.format.asDomain,
                coverURL: row.coverUrl.flatMap(URL.init(string:)),
                rating: row.rating,
                alsoStartedBy: row.alsoStartedBy,
                inLibrary: row.inLibrary
            )
        }
        return CursorPage(items: events, hasMore: page.nextCursor != nil, endCursor: page.nextCursor)
    }

    /// Everything announced across the reader's follows.
    static func upcoming() async throws -> [UpcomingRelease] {
        #if DEBUG
        if Showcase.isOn { return [] }
        #endif
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.UpcomingReleasesQuery()
        )
        return data.upcomingReleases.compactMap { row -> UpcomingRelease? in
            guard let source = row.source.value.flatMap({ ReleaseSource(rawValue: $0.rawValue.lowercased()) })
            else { return nil }
            return UpcomingRelease(
                id: row.id,
                source: source,
                format: row.format.asDomain,
                title: row.title,
                authors: row.authors,
                date: row.date,
                coverURL: row.coverUrl.flatMap(URL.init(string:)),
                seriesName: row.series?.name,
                volume: row.series?.volume,
                author: row.author.map {
                    .init(
                        key: $0.key,
                        name: $0.name,
                        favorite: $0.favorite,
                        portraitURL: $0.portraitUrl.flatMap(URL.init(string:))
                    )
                },
                sagaRating: row.sagaRating,
                sagaFavorite: row.sagaFavorite
            )
        }
    }
}
