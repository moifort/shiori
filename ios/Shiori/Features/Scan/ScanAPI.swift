import Foundation

/// What a scan proposes, before the reader has approved anything.
struct ScannedBook {
    let recognized: Bool
    var title: String?
    var authors: [String] = []
    var publisher: String?
    var firstPublishedIn: Int?
    var synopsis: String?
    var genres: [String] = []
    var pageCount: Int?
    var isbn13: String?
    var seriesName: String?
    var volumeNumber: Int?

    /// The draft the review screen edits and `addBook` persists. The series is
    /// deliberately not carried over: membership is resolved server-side on a
    /// scan, and a manually added book has none to claim.
    var asDraft: BookDraft {
        BookDraft(
            title: title ?? "",
            authors: authors,
            publisher: publisher,
            firstPublishedIn: firstPublishedIn,
            synopsis: synopsis,
            genres: genres,
            pageCount: pageCount,
            isbn13: isbn13
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
            publisher: result.publisher,
            firstPublishedIn: result.firstPublishedIn,
            synopsis: result.synopsis,
            genres: result.genres,
            pageCount: result.pageCount,
            isbn13: result.isbn13,
            seriesName: result.series?.name,
            volumeNumber: result.series?.volume
        )
    }
}
