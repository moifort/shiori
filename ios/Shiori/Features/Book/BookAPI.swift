import Foundation

/// Everything the app does to one book. Each call returns the whole record, so
/// a screen never has to guess what the server changed alongside what it asked
/// for — rating a book also marks it read, and the answer says so.
enum BookAPI {
    static func book(id: String) async throws -> Book? {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.BookQuery(id: id)
        )
        return data.book?.fragments.bookDetail.asBook
    }

    static func add(_ draft: BookDraft) async throws -> Book {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.AddBookMutation(input: draft.asInput)
        )
        return data.addBook.fragments.bookDetail.asBook
    }

    static func setStatus(id: String, status: ReadingStatus) async throws -> Book {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.SetReadingStatusMutation(id: id, status: LibraryAPI.graphQLStatus(status))
        )
        return data.setReadingStatus.fragments.bookDetail.asBook
    }

    static func rate(id: String, stars: Int) async throws -> Book {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.RateBookMutation(id: id, rating: stars)
        )
        track(.bookRated(stars: stars))
        return data.rateBook.fragments.bookDetail.asBook
    }

    /// Passing nil deletes the note rather than storing an empty string.
    static func setNote(id: String, note: String?) async throws -> Book {
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = (trimmed?.isEmpty ?? true) ? nil : trimmed
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.SetBookNoteMutation(id: id, note: GraphQLHelpers.graphQLNullable(value))
        )
        return data.setBookNote.fragments.bookDetail.asBook
    }

    static func setHidden(id: String, hidden: Bool) async throws -> Book {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.SetBookHiddenMutation(id: id, hidden: hidden)
        )
        return data.setBookHidden.fragments.bookDetail.asBook
    }

    static func delete(id: String) async throws {
        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.DeleteBookMutation(id: id)
        )
    }
}

/// A book about to be created, from a scan the reader reviewed, from a form they
/// typed, or from a volume they picked out of a series catalogue.
struct BookDraft {
    var title: String
    var authors: [String] = []
    var publisher: String?
    var firstPublishedIn: Int?
    var synopsis: String?
    var genres: [String] = []
    var pageCount: Int?
    var isbn13: String?
    var status: ReadingStatus = .toRead
    var hidden = false

    var asInput: ShioriGraphQL.NewBookInput {
        ShioriGraphQL.NewBookInput(
            authors: GraphQLHelpers.graphQLNullable(authors.isEmpty ? nil : authors),
            firstPublishedIn: GraphQLHelpers.graphQLNullable(firstPublishedIn),
            genres: GraphQLHelpers.graphQLNullable(genres.isEmpty ? nil : genres),
            hidden: .some(hidden),
            isbn13: GraphQLHelpers.graphQLNullable(isbn13),
            pageCount: GraphQLHelpers.graphQLNullable(pageCount),
            publisher: GraphQLHelpers.graphQLNullable(publisher),
            status: .some(LibraryAPI.graphQLStatus(status)),
            synopsis: GraphQLHelpers.graphQLNullable(synopsis),
            title: title
        )
    }
}
