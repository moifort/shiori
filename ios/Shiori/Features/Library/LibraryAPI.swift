import Foundation
import ShioriGraphQL

/// The library, as the app talks to it. One place maps the generated GraphQL
/// types onto the domain model, so no screen ever touches a generated type.
enum LibraryAPI {
    static func library(status: ReadingStatus? = nil) async throws -> [LibrarySection] {
        let query = LibraryQuery(
            status: GraphQLHelpers.graphQLNullable(status.map(Self.graphQLStatus))
        )
        let data = try await GraphQLHelpers.fetch(GraphQLClient.shared.apollo, query: query)
        return data.library.map { section in
            LibrarySection(
                seriesId: section.seriesId,
                seriesName: section.series,
                books: section.books.map { $0.fragments.bookSummary.asBook }
            )
        }
    }

    static func currentlyReading() async throws -> [Book] {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: CurrentlyReadingQuery()
        )
        return data.currentlyReading.map { $0.fragments.bookSummary.asBook }
    }

    static func graphQLStatus(_ status: ReadingStatus) -> GraphQLEnum<ShioriGraphQL.ReadingStatus> {
        switch status {
        case .toRead: .case(.toRead)
        case .reading: .case(.reading)
        case .read: .case(.read)
        }
    }
}
