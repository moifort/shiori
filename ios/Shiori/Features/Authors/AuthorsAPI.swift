import Foundation

enum AuthorsAPI {
    /// How long the app waits for an author's page. The first opening, by
    /// anyone, builds the author's catalogue with a web-grounded model call and
    /// a Wikipedia lookup, which a cold function can stretch past the session's
    /// 60 s; every later one reads it at once.
    private static let firstOpeningTimeout: TimeInterval = 120

    /// An author's page. Nil when the reader no longer holds a book of theirs.
    static func page(key: String) async throws -> AuthorPage? {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.AuthorPageQuery(key: key),
            requestTimeout: firstOpeningTimeout
        )
        guard let page = data.authorPage else { return nil }
        let author = page.author
        return AuthorPage(
            author: FollowedAuthor(
                key: author.key,
                name: author.name,
                indexLetter: author.indexLetter,
                portraitURL: author.portraitUrl.flatMap(URL.init(string:)),
                bookCount: author.bookCount,
                seriesCount: author.seriesCount,
                favoriteCount: author.favoriteCount,
                averageRating: author.averageRating,
                books: []
            ),
            readCount: author.readCount,
            nationality: page.catalogue?.nationality,
            birthYear: page.catalogue?.birthYear,
            deathYear: page.catalogue?.deathYear,
            biography: page.catalogue?.biography,
            sagas: page.sagas.map { saga in
                SeriesAPI.followedRow(
                    saga.fragments.followedSeriesRow,
                    volumes: saga.volumes.map(\.fragments.followedVolume),
                    spine: saga.catalogue?.spine.map(\.fragments.volumeEntry)
                )
            },
            printSagasNotHeld: page.printSagasNotHeld.map { AuthorSeries($0.fragments.authorSeriesFields) },
            books: page.books.map { $0.fragments.bookSummary.asBook },
            booksNotHeld: page.booksNotHeld.map { AuthorWork(
                    title: $0.title,
                    publishedIn: $0.publishedIn,
                    coverURL: $0.coverUrl.flatMap(URL.init(string:))
                ) }
        )
    }

    /// Asks the world about the author again, for a page that came out empty
    /// or thin: the fresh catalogue replaces the stored one, for everyone.
    /// False when it could not be rebuilt, in which case the old one stands.
    /// One grounded model call, so it waits as long as a first opening does.
    static func refresh(key: String) async throws -> Bool {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.RefreshAuthorMutation(key: key),
            requestTimeout: firstOpeningTimeout,
            changesLibrary: false
        )
        return data.refreshAuthor != nil
    }

    /// One page of the authors the reader holds books of, in the order the
    /// shelf is drawn in.
    static func myAuthorsPage(
        limit: Int,
        offset: Int,
        order: AuthorListOrder
    ) async throws -> (items: [FollowedAuthor], hasMore: Bool) {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.MyAuthorsPageQuery(
                limit: .some(Int32(limit)),
                offset: .some(Int32(offset)),
                favorite: .none,
                order: .some(.case(order == .name ? .name : .loved))
            )
        )
        return (
            items: data.myAuthorsPage.items.map { item in
                FollowedAuthor(
                    key: item.key,
                    name: item.name,
                    indexLetter: item.indexLetter,
                    portraitURL: item.portraitUrl.flatMap(URL.init(string:)),
                    bookCount: item.bookCount,
                    seriesCount: item.seriesCount,
                    favoriteCount: item.favoriteCount,
                    averageRating: item.averageRating,
                    books: item.books.map(\.fragments.followedVolume.asBook)
                )
            },
            hasMore: data.myAuthorsPage.hasMore
        )
    }
}

private extension AuthorSeries {
    init(_ saga: ShioriGraphQL.AuthorSeriesFields) {
        self.init(
            id: saga.id,
            name: saga.name,
            author: saga.author,
            volumeCount: saga.volumeCount,
            firstVolumeTitle: saga.firstVolumeTitle,
            coverURL: saga.coverUrl.flatMap(URL.init(string:))
        )
    }
}
