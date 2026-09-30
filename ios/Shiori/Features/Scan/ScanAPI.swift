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
    /// The language of the photographed edition, read off the cover: the
    /// object on the shelf, not the language the work was written in. Nil
    /// when the cover did not say.
    var language: BookLanguage?
    /// The publisher's cover, found by ISBN server-side and already checked to exist.
    var coverURL: URL?
    var series: SeriesMembership?
    /// The record the reader already keeps of this book — same title and
    /// author, or same ISBN. A warning on the review, never a refusal: a
    /// second edition is a choice some readers make.
    var ownedCopy: Book?

    /// The draft the review screen edits and `addBook` persists.
    ///
    /// The series rides along untouched. It is resolved server-side and keyed to
    /// the shared catalogue, so handing it straight back is what makes a scanned
    /// book join the very catalogue the scan built — and the review screen shows
    /// it read-only for the same reason.
    ///
    /// The edition is presumed in the app's language rather than taken from
    /// the cover, which the review then lets the reader switch.
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
            language: BookLanguage.presumed(scanned: language),
            coverURL: coverURL,
            series: series
        )
    }
}

/// One book a typed title may mean, offered before the full lookup runs.
struct TitleCandidate: Identifiable, Hashable {
    let title: String
    let authors: [String]
    let firstPublishedIn: Int?
    let seriesName: String?
    let volume: Int?

    var id: String { "\(title)|\(authors.joined(separator: ","))" }

    /// What the full lookup is asked: the author beside the title names the
    /// book without ambiguity, as the saga and author screens already ask it.
    var lookUpQuery: String {
        authors.first.map { "\(title) — \($0)" } ?? title
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
            requestTimeout: requestTimeout,
            // A proposal: nothing reaches the library before `addBook`.
            changesLibrary: false
        )
        return ScannedBook(fields: data.scanBook.fragments.scannedRecord)
    }

    /// The same proposal from a page the reader shared. A page that leads
    /// nowhere comes back unrecognized and costs nothing.
    static func lookUp(link: String) async throws -> ScannedBook {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.ScanLinkMutation(url: link),
            requestTimeout: requestTimeout,
            // A proposal: nothing reaches the library before `addBook`.
            changesLibrary: false
        )
        return ScannedBook(fields: data.scanLink.fragments.scannedRecord)
    }

    /// The books a typed title may mean, most likely first. Quick, and spends
    /// no scan: the lookup that follows the reader's pick does. Throws
    /// `APIError.domain(code: "QUOTA_EXHAUSTED")` once nothing is left.
    static func searchTitle(_ title: String) async throws -> [TitleCandidate] {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.SearchTitleMutation(title: title),
            // Nothing is built or saved: the reader only picks a book.
            changesLibrary: false
        )
        return data.searchTitle.map { candidate in
            TitleCandidate(
                title: candidate.title,
                authors: candidate.authors,
                firstPublishedIn: candidate.firstPublishedIn,
                seriesName: candidate.seriesName,
                volume: candidate.volume
            )
        }
    }

    /// The same proposal from a title typed as remembered. Always spends one
    /// scan: there is no cover to have cached.
    static func lookUp(title: String) async throws -> ScannedBook {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.LookUpTitleMutation(title: title),
            requestTimeout: requestTimeout,
            // A proposal: nothing reaches the library before `addBook`.
            changesLibrary: false
        )
        return ScannedBook(fields: data.scanTitle.fragments.scannedRecord)
    }
}

extension ScannedBook {
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
            language: result.language?.asDomain,
            coverURL: result.coverUrl.flatMap(URL.init(string:)),
            series: result.series.map { series in
                SeriesMembership(
                    id: series.id,
                    name: series.name,
                    volume: series.volume,
                    kind: series.kind.asDomain
                )
            },
            ownedCopy: result.ownedCopy?.fragments.bookSummary.asBook
        )
    }
}
