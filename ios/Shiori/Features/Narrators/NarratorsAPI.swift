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
        return data.narratorPage.map { NarratorPage(fields: $0.fragments.narratorPageFields) }
    }

    /// Corrects what the world knows of the narrator, for every reader.
    /// Answers the page as it now reads. Throws `PORTRAIT_NOT_AN_IMAGE` when
    /// the portrait address serves no image.
    static func correct(key: String, correction: PersonCorrection) async throws -> NarratorPage {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.CorrectNarratorMutation(
                key: key,
                nationality: AuthorsAPI.nullable(correction.nationality),
                birthYear: AuthorsAPI.nullable(correction.birthYear),
                deathYear: AuthorsAPI.nullable(correction.deathYear),
                biography: AuthorsAPI.nullable(correction.biography),
                portraitUrl: correction.portraitURL.map { .some($0.absoluteString) } ?? .none
            )
        )
        return NarratorPage(fields: data.correctNarrator.fragments.narratorPageFields)
    }

    /// The faces the reader may give the narrator: the one drawn now first.
    /// Empty when the reader holds no recording of theirs.
    static func portraitChoices(key: String) async throws -> [PortraitChoice] {
        #if DEBUG
        if Showcase.isOn { return [] }
        #endif
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.NarratorPortraitChoicesQuery(key: key)
        )
        return (data.narratorPortraitChoices ?? []).compactMap { choice in
            URL(string: choice.url).map { url in
                PortraitChoice(source: .init(choice.source), url: url, isCurrent: choice.isCurrent)
            }
        }
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
    init(fields page: ShioriGraphQL.NarratorPageFields) {
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
