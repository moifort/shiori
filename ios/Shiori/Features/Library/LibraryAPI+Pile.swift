import Foundation

extension LibraryAPI {
    /// The pile in sections in a view: one request, one scan of the library.
    /// A section a newer server adds is skipped.
    static func pile(_ view: ShelvesView) async throws -> Pile {
        #if DEBUG
        if Showcase.isOn { return Showcase.pile(view: view) }
        #endif
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.PileQuery(
                format: GraphQLHelpers.graphQLNullable(view.format.map(graphQLFormat)),
                genre: GraphQLHelpers.graphQLNullable(view.genre.map(graphQLGenre)),
                subgenre: GraphQLHelpers.graphQLNullable(view.subgenre)
            )
        )
        return Pile(
            formats: data.pile.formats.map(\.asDomain),
            genres: BookGenre.alphabetical.filter(Set(data.pile.genres.compactMap { $0.value?.asDomain }).contains),
            sections: data.pile.sections.compactMap { section in
                guard let kind = PileSectionKind(rawValue: section.kind.rawValue) else { return nil }
                return PileSection(kind: kind, picks: section.picks.map { pick in
                    var book = pick.book.fragments.bookSummary.asBook
                    book.narrators = pick.book.narrators
                    book.startedAt = pick.book.startedAt.flatMap(GraphQLHelpers.parseISO8601)
                    book.recommendation = pick.book.recommendation.map {
                        BookRecommendation(recommenderName: $0.recommenderName)
                    }
                    return PilePick(
                        book: book,
                        award: pick.award.flatMap { mention in
                            LiteraryAward(rawValue: mention.award.rawValue).map { AwardMention(award: $0, year: mention.year) }
                        }
                    )
                })
            }
        )
    }
}
