import Foundation
import SwiftUI

/// A book the reader does not hold — an edition awaited, an award winner, a
/// discovery, a saga's volume — as every list and its page draw it. One record,
/// built on the server from what the web found of the edition and what its
/// page described: a tile and the page it opens read this, and nothing is
/// merged on the device.
struct Release: Hashable, Codable, Sendable {
    /// The same book, format and edition, whoever shows it.
    var key: String
    /// Its title as shown: the edition's once found, else the original's.
    var title: String
    var originalTitle: String
    var authors: [String]
    /// What the book is: a novel, a manga, a recording.
    var format: BookFormat
    var releaseFormat: ReleaseFormat
    /// The language of the book shown: the original's while nobody announced
    /// the edition, the edition's once found.
    var language: BookLanguage?
    var originalLanguage: BookLanguage?
    var state: AwaitedState
    /// Whether the web was ever searched for it.
    var watched: Bool
    /// `YYYY`, `YYYY-MM` or `YYYY-MM-DD`. Nil until found, and for an edition
    /// announced with no date.
    var date: String?
    var isbn13: String?
    var coverURL: URL?
    /// Where to get it: the recording on Audible, the printed edition on
    /// Amazon. Nil until the edition is found.
    var storeURL: URL?
    /// Its saga, when the server knows which: a volume announced. Nil for an
    /// edition, whose page reads the saga off the reader's copy.
    var series: SeriesMembership?
    var publisher: String?
    var firstPublishedIn: Int?
    var synopsis: String?
    var genre: BookGenre?
    var subgenres: [String] = []
    var pageCount: Int?
    var narrators: [String] = []
    var durationMinutes: Int?
    /// Whether its page's description is kept and fresh. False, opening its
    /// page asks the server to describe it.
    var described = false

    /// Drawn as the shelves draw a book, on its tile and on its page alike. A
    /// recording says no medium.
    func book(id: String) -> Book {
        var book = Book(
            id: id,
            title: title,
            authors: authors,
            format: format,
            coverURL: coverURL,
            status: .toRead
        )
        if format == .audiobook { book.media = [] }
        book.publisher = publisher
        book.firstPublishedIn = firstPublishedIn
        book.synopsis = synopsis
        book.genre = genre
        book.subgenres = subgenres
        book.pageCount = pageCount
        book.isbn13 = isbn13
        book.language = language
        book.series = series
        book.narrators = narrators
        book.durationMinutes = durationMinutes
        return book
    }
}

extension Release {
    /// A release known only by what a list or a fixture says of it: nothing
    /// described yet.
    init(
        key: String,
        title: String,
        originalTitle: String? = nil,
        authors: [String],
        releaseFormat: ReleaseFormat,
        format: BookFormat? = nil,
        language: BookLanguage? = nil,
        originalLanguage: BookLanguage? = nil,
        state: AwaitedState,
        watched: Bool = true,
        date: String? = nil,
        isbn13: String? = nil,
        coverURL: URL? = nil,
        storeURL: URL? = nil,
        series: SeriesMembership? = nil
    ) {
        self.init(
            key: key,
            title: title,
            originalTitle: originalTitle ?? title,
            authors: authors,
            format: format ?? (releaseFormat == .audiobook ? .audiobook : .book),
            releaseFormat: releaseFormat,
            language: language,
            originalLanguage: originalLanguage,
            state: state,
            watched: watched,
            date: date,
            isbn13: isbn13,
            coverURL: coverURL,
            storeURL: storeURL,
            series: series
        )
    }

    init(fields: ShioriGraphQL.ReleaseFields) {
        let state: AwaitedState = switch fields.state.value {
        case .available: .available
        case .announced: .announced
        case .unannounced, nil: .unannounced
        }
        self.init(
            key: fields.key,
            title: fields.title,
            originalTitle: fields.originalTitle,
            authors: fields.authors,
            format: fields.format.asDomain,
            releaseFormat: fields.releaseFormat.value == .audiobook ? .audiobook : .book,
            language: fields.language.asDomain,
            originalLanguage: fields.originalLanguage.asDomain,
            state: state,
            watched: fields.watched,
            date: fields.date,
            isbn13: fields.isbn13,
            coverURL: fields.coverUrl.flatMap(URL.init(string:)),
            storeURL: fields.storeUrl.flatMap(URL.init(string:)),
            series: fields.series.flatMap { series in
                series.seriesId.map {
                    SeriesMembership(id: $0, name: series.name, volume: series.volume, kind: .main)
                }
            },
            publisher: fields.publisher,
            firstPublishedIn: fields.firstPublishedIn,
            synopsis: fields.synopsis,
            genre: fields.genre?.asDomain,
            subgenres: fields.subgenres,
            pageCount: fields.pageCount,
            narrators: fields.narrators,
            durationMinutes: fields.durationMinutes,
            described: fields.described
        )
    }
}

/// What a list showed a release as, which its page asks the server to
/// describe: the server knows the book from it, and nothing of the book is
/// sent.
enum ReleaseItem: Hashable, Sendable {
    case awaitedEdition(id: String)
    case awardWinner(key: String, format: ReleaseFormat)
    case suggestion(id: String, format: ReleaseFormat)
    case sagaVolume(seriesId: String, number: Int)
}

enum ReleaseAPI {
    /// The model looks the book up on the web the first time anybody opens it.
    private static let requestTimeout: TimeInterval = 90

    static func describe(_ item: ReleaseItem) async throws -> Release {
        #if DEBUG
        if Showcase.isOn, let release = Showcase.release(of: item) {
            return release
        }
        #endif
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.DescribeReleaseOfMutation(item: item.input),
            requestTimeout: requestTimeout,
            // A description: nothing reaches the library.
            changesLibrary: false
        )
        return Release(fields: data.describeReleaseOf.fragments.releaseFields)
    }
}

private extension ReleaseItem {
    var input: ShioriGraphQL.ReleaseItemInput {
        switch self {
        case let .awaitedEdition(id):
            ShioriGraphQL.ReleaseItemInput(awaitedEditionId: .some(id))
        case let .awardWinner(key, format):
            ShioriGraphQL.ReleaseItemInput(
                awardWinner: .some(ShioriGraphQL.AwardWinnerReleaseInput(format: .case(format.graphQL), key: key))
            )
        case let .suggestion(id, format):
            ShioriGraphQL.ReleaseItemInput(
                suggestion: .some(ShioriGraphQL.SuggestionReleaseInput(format: .case(format.graphQL), id: id))
            )
        case let .sagaVolume(seriesId, number):
            ShioriGraphQL.ReleaseItemInput(
                sagaVolume: .some(ShioriGraphQL.SagaVolumeReleaseInput(number: number, seriesId: seriesId))
            )
        }
    }
}
