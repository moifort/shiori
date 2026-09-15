import Foundation

/// What a scan proposes, before the reader has approved anything.
struct ScannedBook {
    let recognized: Bool
    var title: String?
    var authors: [String] = []
    /// Absent when the cover did not say; the draft then proposes a plain book.
    var format: BookFormat?
    var publisher: String?
    var firstPublishedIn: Int?
    var synopsis: String?
    var genres: [String] = []
    var pageCount: Int?
    var isbn13: String?
    var series: SeriesMembership?

    /// The draft the review screen edits and `addBook` persists.
    ///
    /// The series rides along untouched. It is resolved server-side and keyed to
    /// the shared catalogue, so handing it straight back is what makes a scanned
    /// book join the very catalogue the scan built — and the review screen shows
    /// it read-only for the same reason.
    var asDraft: BookDraft {
        BookDraft(
            title: title ?? "",
            authors: authors,
            format: format ?? .book,
            publisher: publisher,
            firstPublishedIn: firstPublishedIn,
            synopsis: synopsis,
            genres: genres,
            pageCount: pageCount,
            isbn13: isbn13,
            series: series
        )
    }
}

enum ScanAPI {
    /// Spends one scan of the allowance, unless the cover was already scanned.
    /// Throws `APIError.domain(code: "QUOTA_EXHAUSTED")` once nothing is left,
    /// which the view model turns into the paywall rather than an error alert.
    static func scan(jpeg: Data) async throws -> ScannedBook {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.ScanBookMutation(imageBase64: jpeg.base64EncodedString())
        )
        let result = data.scanBook
        return ScannedBook(
            recognized: result.recognized,
            title: result.title,
            authors: result.authors,
            format: result.format?.asDomain,
            publisher: result.publisher,
            firstPublishedIn: result.firstPublishedIn,
            synopsis: result.synopsis,
            genres: result.genres,
            pageCount: result.pageCount,
            isbn13: result.isbn13,
            series: result.series.map { series in
                SeriesMembership(
                    id: series.id,
                    name: series.name,
                    volume: series.volume,
                    kind: series.kind.asDomain
                )
            }
        )
    }
}
