import Foundation

enum AuthorsAPI {
    /// How long the app waits for an author's page. The first opening, by
    /// anyone, builds the author's catalogue with a web-grounded model call and
    /// a Wikipedia lookup, which a cold function can stretch past the session's
    /// 60 s; every later one reads it at once.
    private static let firstOpeningTimeout: TimeInterval = 120

    /// An author's page. Nil when the reader no longer holds a book of theirs,
    /// unless `offered` names them: an author a friend loves, opened from
    /// Découvrir, whose page is then built for a reader who holds nothing.
    /// `waitForCatalogue` false answers at once for an author nobody described,
    /// with `isAwaitingCatalogue` set; true waits while the AI builds it.
    static func page(key: String, offered: String? = nil, waitForCatalogue: Bool = false) async throws -> AuthorPage? {
        #if DEBUG
        if Showcase.isOn { return Showcase.authorPage(key: key) }
        #endif
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.AuthorPageQuery(
                key: key,
                offered: offered.map { .some($0) } ?? .none,
                waitForCatalogue: waitForCatalogue
            ),
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
                shelvedAt: nil,
                books: [],
                favorite: author.favorite
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
                    catalogue: saga.catalogue?.fragments.catalogueSpine
                )
            },
            sagasNotHeld: page.sagasNotHeld.map { AuthorSeries($0.fragments.authorSeriesFields) },
            books: page.books.map { $0.fragments.bookSummary.asBook },
            booksNotHeld: page.booksNotHeld.map { AuthorWork(
                    title: $0.title,
                    publishedIn: $0.publishedIn,
                    coverURL: $0.coverUrl.flatMap(URL.init(string:))
                ) },
            isAwaitingCatalogue: page.awaitingCatalogue
        )
    }


    /// Hearts the author, or takes the heart back. Answers what is now true.
    static func setFavorite(key: String, favorite: Bool) async throws -> Bool {
        #if DEBUG
        if Showcase.isOn { return favorite }
        #endif
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.SetAuthorFavoriteMutation(key: key, favorite: favorite)
        )
        return data.setAuthorFavorite
    }

    /// One page of the authors the reader holds books of, in the order the
    /// shelf is drawn in.
    static func myAuthorsPage(
        limit: Int,
        after: String?,
        order: AuthorListOrder
    ) async throws -> CursorPage<FollowedAuthor> {
        #if DEBUG
        if Showcase.isOn {
            return Showcase.authorsPage(limit: limit, after: after, order: order)
        }
        #endif
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.MyAuthorsPageQuery(
                limit: .some(Int32(limit)),
                after: after.map { .some($0) } ?? .none,
                favorite: .none,
                order: .some(.case(order.graphQL))
            )
        )
        return CursorPage(
            items: data.myAuthorsPage.items.map { FollowedAuthor(row: $0.fragments.followedAuthorRow) },
            hasMore: data.myAuthorsPage.hasMore,
            endCursor: data.myAuthorsPage.endCursor
        )
    }
}

extension FollowedAuthor {
    /// An author as the Authors shelf draws their row, in the Library and on
    /// Découvrir alike.
    init(row: ShioriGraphQL.FollowedAuthorRow) {
        self.init(
            key: row.key,
            name: row.name,
            indexLetter: row.indexLetter,
            portraitURL: row.portraitUrl.flatMap(URL.init(string:)),
            bookCount: row.bookCount,
            seriesCount: row.seriesCount,
            favoriteCount: row.favoriteCount,
            averageRating: row.averageRating,
            shelvedAt: GraphQLHelpers.parseISO8601(row.shelvedAt),
            books: row.books.map(\.fragments.bookSummary.asBook),
            favorite: row.favorite
        )
    }
}

private extension AuthorSeries {
    init(_ saga: ShioriGraphQL.AuthorSeriesFields) {
        self.init(
            id: saga.id,
            name: saga.name,
            isAudio: saga.audio,
            author: saga.author,
            volumeCount: saga.volumeCount,
            firstVolumeTitle: saga.firstVolumeTitle,
            coverURL: saga.coverUrl.flatMap(URL.init(string:))
        )
    }
}
