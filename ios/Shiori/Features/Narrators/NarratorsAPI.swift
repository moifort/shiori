import Foundation

enum NarratorsAPI {
    /// A narrator's page. Nil when the reader holds no recording of theirs,
    /// unless `offered` names them. `waitForCatalogue` false answers at once
    /// for a narrator nobody described, the AI not asked yet.
    static func page(key: String, offered: String?, waitForCatalogue: Bool = false) async throws -> NarratorPage? {
        #if DEBUG
        if Showcase.isOn { return Showcase.narratorPage(key: key) }
        #endif
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.NarratorPageQuery(
                key: key,
                offered: offered.map { .some($0) } ?? .none,
                waitForCatalogue: waitForCatalogue
            )
        )
        return data.narratorPage.map(NarratorPage.init(page:))
    }

    /// Hearts the narrator, or takes the heart back. Answers what is now true.
    static func setFavorite(key: String, favorite: Bool) async throws -> Bool {
        #if DEBUG
        if Showcase.isOn { return favorite }
        #endif
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.SetNarratorFavoriteMutation(key: key, favorite: favorite)
        )
        return data.setNarratorFavorite
    }
}

private extension NarratorPage {
    init(page: ShioriGraphQL.NarratorPageQuery.Data.NarratorPage) {
        let narrator = page.narrator
        self.init(
            key: narrator.key,
            name: narrator.name,
            portraitURL: narrator.portraitUrl.flatMap(URL.init(string:)),
            favorite: narrator.favorite,
            bookCount: narrator.bookCount,
            readCount: narrator.readCount,
            seriesCount: narrator.seriesCount,
            averageRating: narrator.averageRating,
            sagas: page.sagas.map { saga in
                SeriesAPI.followedRow(
                    saga.fragments.followedSeriesRow,
                    volumes: saga.volumes.map(\.fragments.followedVolume),
                    catalogue: saga.catalogue?.fragments.catalogueSpine
                )
            },
            books: page.books.map { $0.fragments.bookSummary.asBook },
            nationality: page.catalogue?.nationality,
            birthYear: page.catalogue?.birthYear,
            deathYear: page.catalogue?.deathYear,
            biography: page.catalogue?.biography,
            isAwaitingCatalogue: page.awaitingCatalogue
        )
    }
}
