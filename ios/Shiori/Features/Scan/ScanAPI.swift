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
    var genre: BookGenre?
    var subgenres: [String] = []
    var pageCount: Int?
    var isbn13: String?
    /// The publisher's cover, found by ISBN server-side and already checked to exist.
    var coverURL: URL?
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
            genre: genre,
            subgenres: subgenres,
            pageCount: pageCount,
            isbn13: isbn13,
            coverURL: coverURL,
            series: series
        )
    }
}

enum ScanAPI {
    /// How long the app waits for a scan: the function's own ceiling
    /// (`timeout_seconds` in infra/function.tf) plus a margin, so a request that
    /// runs over receives the server's 504 instead of both sides giving up at the
    /// same instant. The session default of 60 s is what a cold scan, measured
    /// at 55 s, kept running into.
    private static let requestTimeout: TimeInterval = 190

    /// Spends one scan of the allowance, unless the cover was already scanned.
    /// Throws `APIError.domain(code: "QUOTA_EXHAUSTED")` once nothing is left,
    /// which the view model turns into the paywall rather than an error alert.
    static func scan(jpeg: Data) async throws -> ScannedBook {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.ScanBookMutation(imageBase64: jpeg.base64EncodedString()),
            requestTimeout: requestTimeout
        )
        return ScannedBook(fields: data.scanBook.fragments.scannedRecord)
    }

    /// The same proposal from a page the reader shared. A page that leads
    /// nowhere comes back unrecognized and costs nothing.
    static func lookUp(link: String) async throws -> ScannedBook {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.ScanLinkMutation(url: link),
            requestTimeout: requestTimeout
        )
        return ScannedBook(fields: data.scanLink.fragments.scannedRecord)
    }

    /// The same proposal from a title typed as remembered. Always spends one
    /// scan: there is no cover to have cached.
    static func lookUp(title: String) async throws -> ScannedBook {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.LookUpTitleMutation(title: title),
            requestTimeout: requestTimeout
        )
        return ScannedBook(fields: data.scanTitle.fragments.scannedRecord)
    }
}

private extension ScannedBook {
    init(fields result: ShioriGraphQL.ScannedRecord) {
        self.init(
            recognized: result.recognized,
            title: result.title,
            authors: result.authors,
            format: result.format?.asDomain,
            publisher: result.publisher,
            firstPublishedIn: result.firstPublishedIn,
            synopsis: result.synopsis,
            genre: result.genre?.asDomain,
            subgenres: result.subgenres,
            pageCount: result.pageCount,
            isbn13: result.isbn13,
            coverURL: result.coverUrl.flatMap(URL.init(string:)),
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
