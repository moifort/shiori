import Foundation
import SwiftUI

/// A book Découvrir shows — a saga's volume, an edition awaited, an award
/// winner — named by what the app already knows of it, to be described for
/// its page.
struct ReleaseSeed: Hashable, Sendable {
    var title: String
    var authors: [String]
    var format: BookFormat
    /// The edition's language. Nil, the book is described in the app's.
    var language: BookLanguage?
    var series: SeriesMembership?
    /// The ISBN the web search found, for the model to check.
    var isbn13: String?
    /// `YYYY`, `YYYY-MM` or `YYYY-MM-DD`, as found.
    var releasedOn: String?
    var coverURL: URL?
}

/// A book described for its page: the record a scan would propose, and what
/// only a recording has.
struct ReleaseDescription: Sendable {
    let book: ScannedBook
    let narrators: [String]
    let durationMinutes: Int?
}

extension Book {
    /// The book as its page draws it once described: what the app already
    /// showed stays — the title, the cover, the saga, the date — and what the
    /// model and Audible found fills in the rest. A recording says no medium,
    /// described or not.
    func described(by description: ReleaseDescription?) -> Book {
        var book = self
        // A recording is heard: it is held on no paper nor screen.
        if book.format == .audiobook { book.media = [] }
        guard let description else { return book }
        let found = description.book
        book.publisher = book.publisher ?? found.publisher
        book.firstPublishedIn = book.firstPublishedIn ?? found.firstPublishedIn
        book.synopsis = book.synopsis ?? found.synopsis
        book.genre = book.genre ?? found.genre
        if book.subgenres.isEmpty { book.subgenres = found.subgenres }
        if book.format != .audiobook {
            book.pageCount = book.pageCount ?? found.pageCount
            book.isbn13 = book.isbn13 ?? found.isbn13
        }
        book.language = book.language ?? found.language
        book.coverURL = book.coverURL ?? found.coverURL
        if book.series == nil { book.series = found.series }
        if book.narrators.isEmpty { book.narrators = description.narrators }
        book.durationMinutes = book.durationMinutes ?? description.durationMinutes
        return book
    }
}

/// Asks for a shown book's description when its page opens, and keeps it for
/// the page to draw. A page that could not have one — the allowance used up,
/// or the model failing — stays the plain page it opened as.
@MainActor
@Observable
final class ReleaseDescriber {
    private(set) var description: ReleaseDescription?
    private(set) var isDescribing = false

    func describe(_ seed: ReleaseSeed) async {
        guard description == nil, !isDescribing else { return }
        isDescribing = true
        defer { isDescribing = false }
        do {
            let found = try await ReleaseAPI.describe(seed)
            withAnimation(.smooth) { description = found }
        } catch {
            guard !isCancellation(error), (error as? APIError)?.domainCode != "QUOTA_EXHAUSTED" else { return }
            _ = reportError(error)
        }
    }
}

/// Under a shown book's facts: a row while its description is being written,
/// then its summary.
struct ReleaseDescriptionSections: View {
    let describer: ReleaseDescriber
    let synopsis: String?

    var body: some View {
        if describer.isDescribing {
            Section {
                HStack(alignment: .top, spacing: 12) {
                    ProgressView()
                    Text("Préparation de la fiche…")
                        .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("release-describing")
            }
        } else if let synopsis, !synopsis.isEmpty {
            BookSynopsisSection(synopsis: synopsis)
        }
    }
}

enum ReleaseAPI {
    /// The model looks the book up on the web the first time anybody opens it.
    private static let requestTimeout: TimeInterval = 90

    static func describe(_ seed: ReleaseSeed) async throws -> ReleaseDescription {
        let membership = seed.series.flatMap { $0.id.isEmpty ? nil : $0 }
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.DescribeReleaseMutation(
                book: ShioriGraphQL.ReleaseInput(
                    authors: seed.authors,
                    coverUrl: GraphQLHelpers.graphQLNullable(seed.coverURL?.absoluteString),
                    format: LibraryAPI.graphQLFormat(seed.format),
                    isbn13: GraphQLHelpers.graphQLNullable(seed.isbn13),
                    language: GraphQLHelpers.graphQLNullable(seed.language.map(LibraryAPI.graphQLLanguage)),
                    releasedOn: GraphQLHelpers.graphQLNullable(seed.releasedOn),
                    seriesId: GraphQLHelpers.graphQLNullable(membership?.id),
                    seriesName: GraphQLHelpers.graphQLNullable(membership?.name),
                    title: seed.title,
                    volume: GraphQLHelpers.graphQLNullable(membership?.volume)
                )
            ),
            requestTimeout: requestTimeout,
            // A description: nothing reaches the library.
            changesLibrary: false
        )
        let answer = data.describeRelease
        return ReleaseDescription(
            book: ScannedBook(fields: answer.book.fragments.scannedRecord),
            narrators: answer.narrators,
            durationMinutes: answer.durationMinutes
        )
    }
}
