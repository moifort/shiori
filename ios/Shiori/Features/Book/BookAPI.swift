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
            concerning: .book(id: id),
            mutation: ShioriGraphQL.SetReadingStatusMutation(id: id, status: LibraryAPI.graphQLStatus(status))
        )
        return data.setReadingStatus.fragments.bookDetail.asBook
    }

    /// Sends only what the reader changed: an untouched field is left out, and a
    /// field they emptied is sent as null, which the server clears.
    static func update(id: String, correction: BookCorrection) async throws -> Book {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            concerning: .book(id: id),
            mutation: ShioriGraphQL.UpdateBookMutation(id: id, input: correction.asInput)
        )
        return data.updateBook.fragments.bookDetail.asBook
    }

    /// Saves the edit sheet in one request: the correction when there is one,
    /// then the stars when they changed — `rating` nil takes them back. Answers
    /// with the book as the last write left it, or nil when there was nothing
    /// to send.
    static func save(id: String, correction: BookCorrection, rating: Int??) async throws -> Book? {
        let correct = !correction.isEmpty
        let rate = rating.flatMap { $0 }
        let unrate = rating.map { $0 == nil } ?? false
        guard correct || rate != nil || unrate else { return nil }
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            concerning: .book(id: id),
            mutation: ShioriGraphQL.SaveBookMutation(
                id: id,
                input: correction.asInput,
                correct: correct,
                rating: rate.map { .some($0) } ?? .none,
                rate: rate != nil,
                unrate: unrate
            )
        )
        if let rate { track(.bookRated(stars: rate)) }
        // The last write run is the book as it now stands.
        let saved = data.removeBookRating?.fragments.bookDetail
            ?? data.rateBook?.fragments.bookDetail
            ?? data.updateBook?.fragments.bookDetail
        return saved?.asBook
    }

    static func rate(id: String, stars: Int) async throws -> Book {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            concerning: .book(id: id),
            mutation: ShioriGraphQL.RateBookMutation(id: id, rating: stars)
        )
        track(.bookRated(stars: stars))
        return data.rateBook.fragments.bookDetail.asBook
    }

    static func setHidden(id: String, hidden: Bool) async throws -> Book {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            concerning: .book(id: id),
            mutation: ShioriGraphQL.SetBookHiddenMutation(id: id, hidden: hidden)
        )
        return data.setBookHidden.fragments.bookDetail.asBook
    }

    /// Toggle the heart without touching the star rating: the two say different
    /// things and a reader may hold either without the other.
    static func setFavorite(id: String, favorite: Bool) async throws -> Book {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            concerning: .book(id: id),
            mutation: ShioriGraphQL.SetBookFavoriteMutation(id: id, favorite: favorite)
        )
        return data.setBookFavorite.fragments.bookDetail.asBook
    }

    /// Records who recommended the book, replacing what was there. Nil forgets
    /// it; so does a recommendation whose two halves are empty.
    static func setRecommendation(id: String, recommendation: BookRecommendation?) async throws -> Book {
        let input = recommendation.map {
            ShioriGraphQL.RecommendationInput(
                comment: GraphQLHelpers.graphQLNullable($0.comment),
                recommenderName: GraphQLHelpers.graphQLNullable($0.recommenderName)
            )
        }
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            concerning: .book(id: id),
            mutation: ShioriGraphQL.SetBookRecommendationMutation(
                id: id,
                recommendation: input.map { .some($0) } ?? .null
            )
        )
        return data.setBookRecommendation.fragments.bookDetail.asBook
    }

    /// Every subgenre the reader has used, most used first. What the subgenre
    /// field proposes: a vocabulary drawn from their own shelf.
    /// The edit form's proposals, both lists in one request: the subgenres the
    /// reader has used and the sagas they hold, each saga named once.
    static func vocabulary() async throws -> (subgenres: [String], sagas: [String]) {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.EditVocabularyQuery()
        )
        return (data.vocabulary.subgenres, data.vocabulary.sagas)
    }

    static func subgenres() async throws -> [String] {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.SubgenresQuery()
        )
        return data.subgenres
    }

    static func delete(id: String) async throws {
        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            concerning: .book(id: id),
            mutation: ShioriGraphQL.DeleteBookMutation(id: id)
        )
    }
}

/// A book about to be created, from a scan the reader reviewed, from a form they
/// typed, or from a volume they picked out of a series catalogue.
struct BookDraft {
    var title: String
    var authors: [String] = []
    var format: BookFormat = .book
    var publisher: String?
    var firstPublishedIn: Int?
    var synopsis: String?
    var genre: BookGenre?
    var subgenres: [String] = []
    var pageCount: Int?
    var isbn13: String?
    /// The language of the edition: read off the cover by a scan, or the
    /// edition of the saga a volume is added to. Nil when nothing said, and
    /// the book then shelves apart from any edition that did.
    var language: BookLanguage?
    /// Only ever filled from a scan, like the series: it was found for the scanned
    /// ISBN, and the server is what vouches it exists.
    var coverURL: URL?
    /// Only ever filled from a scan: membership is keyed to the shared catalogue,
    /// and a hand-typed saga would be one no catalogue knows.
    var series: SeriesMembership?
    var status: ReadingStatus = .toRead
    var hidden = false

    var asInput: ShioriGraphQL.NewBookInput {
        ShioriGraphQL.NewBookInput(
            authors: GraphQLHelpers.graphQLNullable(authors.isEmpty ? nil : authors),
            coverUrl: GraphQLHelpers.graphQLNullable(coverURL?.absoluteString),
            firstPublishedIn: GraphQLHelpers.graphQLNullable(firstPublishedIn),
            format: .some(LibraryAPI.graphQLFormat(format)),
            genre: GraphQLHelpers.graphQLNullable(genre.map(LibraryAPI.graphQLGenre)),
            hidden: .some(hidden),
            isbn13: GraphQLHelpers.graphQLNullable(isbn13),
            language: GraphQLHelpers.graphQLNullable(language.map(LibraryAPI.graphQLLanguage)),
            pageCount: GraphQLHelpers.graphQLNullable(pageCount),
            publisher: GraphQLHelpers.graphQLNullable(publisher),
            series: GraphQLHelpers.graphQLNullable(
                series.map { membership in
                    ShioriGraphQL.SeriesMembershipInput(
                        id: membership.id,
                        kind: .case(LibraryAPI.graphQLVolumeKind(membership.kind)),
                        name: membership.name,
                        volume: GraphQLHelpers.graphQLNullable(membership.volume)
                    )
                }
            ),
            status: .some(LibraryAPI.graphQLStatus(status)),
            subgenres: GraphQLHelpers.graphQLNullable(subgenres.isEmpty ? nil : subgenres),
            synopsis: GraphQLHelpers.graphQLNullable(synopsis),
            title: title
        )
    }
}

/// A saga named by hand in the edit form: a name, and a volume number when the
/// volume has one.
struct SeriesPlacement: Equatable, Sendable {
    var name: String
    var volume: Int?
}

/// What the reader changed on a book in the edit form. A nil property was not
/// touched and is not sent; `.clear` empties a field the reader deleted.
struct BookCorrection: Equatable, Sendable {
    enum Change<Value: Equatable & Sendable>: Equatable, Sendable {
        case set(Value)
        case clear
    }

    var title: String?
    var authors: [String]?
    var format: BookFormat?
    var publisher: Change<String>?
    var firstPublishedIn: Change<Int>?
    var synopsis: Change<String>?
    var genre: Change<BookGenre>?
    var subgenres: [String]?
    var pageCount: Change<Int>?
    var durationMinutes: Change<Int>?
    var narrators: [String]?
    var isbn13: Change<String>?
    var language: Change<BookLanguage>?
    /// The saga as the reader names it. The server works out which saga that
    /// is, so the book joins the one its siblings already sit in.
    var series: Change<SeriesPlacement>?
    /// The reading dates, corrected by hand. Never cleared: they follow from
    /// the status, and moving the book along the pile is what clears them.
    var addedAt: Date?
    var startedAt: Date?
    var finishedAt: Date?

    var isEmpty: Bool { self == BookCorrection() }

    var asInput: ShioriGraphQL.BookEditInput {
        ShioriGraphQL.BookEditInput(
            addedAt: Self.nullable(addedAt.map(GraphQLHelpers.iso8601)),
            authors: Self.nullable(authors),
            durationMinutes: Self.nullable(durationMinutes),
            finishedAt: Self.nullable(finishedAt.map(GraphQLHelpers.iso8601)),
            firstPublishedIn: Self.nullable(firstPublishedIn),
            format: format.map { .some(LibraryAPI.graphQLFormat($0)) } ?? .none,
            genre: Self.nullableGenre(genre),
            isbn13: Self.nullable(isbn13),
            language: Self.nullableLanguage(language),
            narrators: Self.nullable(narrators),
            pageCount: Self.nullable(pageCount),
            publisher: Self.nullable(publisher),
            series: Self.nullableSeries(series),
            startedAt: Self.nullable(startedAt.map(GraphQLHelpers.iso8601)),
            subgenres: Self.nullable(subgenres),
            synopsis: Self.nullable(synopsis),
            title: Self.nullable(title)
        )
    }

    private static func nullableSeries(
        _ change: Change<SeriesPlacement>?
    ) -> GraphQLNullable<ShioriGraphQL.SeriesPlacementInput> {
        switch change {
        case nil: .none
        case let .set(placement):
            .some(ShioriGraphQL.SeriesPlacementInput(
                name: placement.name,
                volume: GraphQLHelpers.graphQLNullable(placement.volume)
            ))
        case .clear: .null
        }
    }

    private static func nullable<Value>(_ value: Value?) -> GraphQLNullable<Value> {
        value.map { .some($0) } ?? .none
    }

    private static func nullableGenre(_ change: Change<BookGenre>?) -> GraphQLNullable<GraphQLEnum<ShioriGraphQL.Genre>> {
        switch change {
        case nil: .none
        case let .set(genre): .some(LibraryAPI.graphQLGenre(genre))
        case .clear: .null
        }
    }

    private static func nullableLanguage(
        _ change: Change<BookLanguage>?
    ) -> GraphQLNullable<GraphQLEnum<ShioriGraphQL.BookLanguage>> {
        switch change {
        case nil: .none
        case let .set(language): .some(LibraryAPI.graphQLLanguage(language))
        case .clear: .null
        }
    }

    private static func nullable<Value>(_ change: Change<Value>?) -> GraphQLNullable<Value> {
        switch change {
        case nil: .none
        case let .set(value): .some(value)
        case .clear: .null
        }
    }
}
