import Foundation

/// The library, as the app talks to it. One place maps the generated GraphQL
/// types onto the domain model, so no screen ever touches a generated type.
enum LibraryAPI {
    /// One page of the Library tab, in the order the server shelved it.
    static func libraryPage(
        mode: LibraryMode,
        filter: LibraryFilter?,
        limit: Int,
        after: String?
    ) async throws -> LibraryPageResult {
        #if DEBUG
        if Showcase.isOn {
            return Showcase.libraryPage(mode: mode, filter: filter, limit: limit, after: after)
        }
        #endif
        let query = ShioriGraphQL.LibraryPageQuery(
            favorite: filter == .favorites ? .some(true) : .none,
            loved: mode == .favorites ? .some(true) : .none,
            status: GraphQLHelpers.graphQLNullable(filter?.status.map(Self.graphQLStatus)),
            format: .none,
            genre: .none,
            subgenre: .none,
            limit: .some(Int32(limit)),
            after: GraphQLHelpers.graphQLNullable(after)
        )
        let data = try await GraphQLHelpers.fetch(GraphQLClient.shared.apollo, query: query)
        return LibraryPageResult(
            books: data.libraryPage.books.map { $0.fragments.bookSummary.asBook },
            hasMore: data.libraryPage.hasMore
        )
    }

    /// The Library tab's entry screen in a view: one request, one scan.
    static func shelves(_ view: ShelvesView) async throws -> LibraryShelves {
        #if DEBUG
        if Showcase.isOn { return Showcase.libraryShelves(view: view) }
        #endif
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.LibraryShelvesQuery(
                format: GraphQLHelpers.graphQLNullable(view.format.map(graphQLFormat)),
                genre: GraphQLHelpers.graphQLNullable(view.genre.map(graphQLGenre)),
                subgenre: GraphQLHelpers.graphQLNullable(view.subgenre)
            )
        )
        let shelves = data.libraryShelves
        return LibraryShelves(
            formats: shelves.formats.map(\.asDomain),
            recent: shelves.recent.map(\.fragments.bookSummary.asBook),
            toRead: shelves.toRead.map(\.fragments.bookSummary.asBook),
            readRecently: shelves.readRecently.map(\.fragments.bookSummary.asBook),
            favorites: shelves.favorites.map(\.fragments.bookSummary.asBook),
            hasDropped: shelves.hasDropped,
            genres: shelves.genres.map {
                GenreShelf(
                    genre: $0.genre.asDomain,
                    count: $0.count,
                    coverURL: $0.cover?.coverUrl.flatMap(URL.init(string:))
                )
            },
            subgenres: shelves.subgenres,
            series: shelves.series.map { row in
                SeriesAPI.followedRow(
                    row.fragments.followedSeriesRow,
                    volumes: row.volumes.map(\.fragments.followedVolume),
                    catalogue: row.catalogue?.fragments.catalogueSpine
                )
            },
            authors: shelves.authors.map { author in
                FollowedAuthor(
                    key: author.key,
                    name: author.name,
                    indexLetter: author.indexLetter,
                    portraitURL: author.portraitUrl.flatMap(URL.init(string:)),
                    bookCount: author.bookCount,
                    seriesCount: author.seriesCount,
                    favoriteCount: author.favoriteCount,
                    averageRating: author.averageRating,
                    shelvedAt: GraphQLHelpers.parseISO8601(author.shelvedAt),
                    books: [],
                    favorite: author.favorite
                )
            }
        )
    }

    /// One page of a shelf of the Library tab, in the server's order.
    static func shelfPage(_ query: ShelfQuery, limit: Int, after: String?) async throws -> LibraryPageResult {
        #if DEBUG
        if Showcase.isOn { return Showcase.shelfPage(query, limit: limit, after: after) }
        #endif
        let view = query.view
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.LibraryPageQuery(
                favorite: query.favorite ? .some(true) : .none,
                loved: .none,
                status: GraphQLHelpers.graphQLNullable(query.serverStatus.map(graphQLStatus)),
                format: GraphQLHelpers.graphQLNullable(view.format.map(graphQLFormat)),
                genre: GraphQLHelpers.graphQLNullable(view.genre.map(graphQLGenre)),
                subgenre: GraphQLHelpers.graphQLNullable(view.subgenre),
                limit: .some(Int32(limit)),
                after: GraphQLHelpers.graphQLNullable(after)
            )
        )
        return LibraryPageResult(
            books: data.libraryPage.books.map { $0.fragments.bookSummary.asBook },
            hasMore: data.libraryPage.hasMore
        )
    }

    static func graphQLStatus(_ status: ReadingStatus) -> GraphQLEnum<ShioriGraphQL.ReadingStatus> {
        switch status {
        case .toRead: .case(.toRead)
        case .reading: .case(.reading)
        case .read: .case(.read)
        case .dropped: .case(.dropped)
        }
    }

    static func graphQLLanguage(_ language: BookLanguage) -> GraphQLEnum<ShioriGraphQL.BookLanguage> {
        switch language {
        case .fr: .case(.fr)
        case .en: .case(.en)
        case .es: .case(.es)
        case .de: .case(.de)
        case .it: .case(.it)
        case .pt: .case(.pt)
        case .nl: .case(.nl)
        case .sv: .case(.sv)
        case .pl: .case(.pl)
        case .ru: .case(.ru)
        case .uk: .case(.uk)
        case .tr: .case(.tr)
        case .ar: .case(.ar)
        case .ja: .case(.ja)
        case .zh: .case(.zh)
        case .ko: .case(.ko)
        }
    }

    static func graphQLGenre(_ genre: BookGenre) -> GraphQLEnum<ShioriGraphQL.Genre> {
        switch genre {
        case .fantasy: .case(.fantasy)
        case .scienceFiction: .case(.scienceFiction)
        case .horror: .case(.horror)
        case .crime: .case(.crime)
        case .thriller: .case(.thriller)
        case .romance: .case(.romance)
        case .historicalFiction: .case(.historicalFiction)
        case .adventure: .case(.adventure)
        case .literaryFiction: .case(.literaryFiction)
        case .humor: .case(.humor)
        case .poetry: .case(.poetry)
        case .drama: .case(.drama)
        case .biography: .case(.biography)
        case .history: .case(.history)
        case .essay: .case(.essay)
        case .science: .case(.science)
        case .selfHelp: .case(.selfHelp)
        case .business: .case(.business)
        case .art: .case(.art)
        case .cooking: .case(.cooking)
        case .travel: .case(.travel)
        case .other: .case(.other)
        }
    }

    static func graphQLFormat(_ format: BookFormat) -> GraphQLEnum<ShioriGraphQL.BookFormat> {
        switch format {
        case .book: .case(.book)
        case .audiobook: .case(.audiobook)
        case .bandeDessinee: .case(.bandeDessinee)
        case .comic: .case(.comic)
        case .manga: .case(.manga)
        }
    }

    static func graphQLMedia(_ media: [BookMedium]) -> [GraphQLEnum<ShioriGraphQL.BookMedium>] {
        media.map { medium in
            switch medium {
            case .print: .case(.print)
            case .digital: .case(.digital)
            }
        }
    }

    /// Only ever used to hand a scanned membership straight back to `addBook`.
    static func graphQLVolumeKind(_ kind: VolumeKind) -> ShioriGraphQL.VolumeKind {
        switch kind {
        case .main: .main
        case .prequel: .prequel
        case .spinOff: .spinOff
        case .novella: .novella
        case .companion: .companion
        }
    }
}

/// One page of the library, mirroring the server's `LibraryPage` payload.
struct LibraryPageResult: Sendable {
    let books: [Book]
    let hasMore: Bool
}
