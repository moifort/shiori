import Foundation

/// The library, as the app talks to it. One place maps the generated GraphQL
/// types onto the domain model, so no screen ever touches a generated type.
enum LibraryAPI {
    static func library(status: ReadingStatus? = nil) async throws -> [LibrarySection] {
        let query = ShioriGraphQL.LibraryQuery(
            status: GraphQLHelpers.graphQLNullable(status.map(Self.graphQLStatus))
        )
        let data = try await GraphQLHelpers.fetch(GraphQLClient.shared.apollo, query: query)
        return data.library.map { section in
            LibrarySection(
                seriesId: section.seriesId,
                seriesName: section.series,
                language: section.language?.asDomain,
                books: section.books.map { $0.fragments.bookSummary.asBook }
            )
        }
    }

    static func graphQLStatus(_ status: ReadingStatus) -> GraphQLEnum<ShioriGraphQL.ReadingStatus> {
        switch status {
        case .toRead: .case(.toRead)
        case .reading: .case(.reading)
        case .read: .case(.read)
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
        case .ebook: .case(.ebook)
        case .audiobook: .case(.audiobook)
        case .bandeDessinee: .case(.bandeDessinee)
        case .comic: .case(.comic)
        case .manga: .case(.manga)
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
