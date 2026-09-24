import Foundation

/// How an edition reaches the reader, and the filter the tab is read through —
/// kept between visits.
enum ReleaseFormat: String, Sendable, Hashable, CaseIterable, Identifiable {
    case book, audiobook
    var id: String { rawValue }

    /// The toolbar's word for it: a recording is only ever offered from Audible.
    var filterLabel: String {
        switch self {
        case .book: String(localized: "Livre")
        case .audiobook: String(localized: "Audible")
        }
    }

    var symbol: String {
        switch self {
        case .book: "book"
        case .audiobook: "headphones"
        }
    }
}

/// One edition of a work in one language, out or announced.
struct ReleaseEdition: Identifiable, Hashable, Sendable {
    let title: String
    let volume: Int?
    let format: ReleaseFormat
    /// `YYYY`, `YYYY-MM` or `YYYY-MM-DD`. Nil for an edition out on a date
    /// nobody found.
    let date: String?
    let isbn13: String?
    let coverURL: URL?
    /// For a recording, a search for its title on the reader's own Audible
    /// store: where the reader goes to find it.
    let audibleURL: URL?

    var id: String { "\(format)-\(volume.map(String.init) ?? title)" }

    /// Whether it is still to come — the server's rule, on the phone's calendar.
    var isUpcoming: Bool { date.map { ReleaseDateText.isUpcoming($0) } ?? false }
}

/// A saga the reader follows, or a book they read, in one language: what
/// exists or is announced of it there. A saga read in English whose French
/// translation is announced is two releases, as the Series tab makes two rows.
struct Release: Identifiable, Sendable {
    let key: String
    var id: String { key }
    let isSeries: Bool
    let seriesId: String?
    /// The language of its editions.
    let language: BookLanguage
    /// The language the reader read it in.
    let readIn: BookLanguage
    let title: String
    let author: String?
    let coverURL: URL?
    let nextDate: String?
    let editions: [ReleaseEdition]
    /// For a saga, its row as the Series tab draws it in that language.
    let series: FollowedSeries?

    /// The work as one format shows it: only its editions in that format, and
    /// the soonest of those still to come. Nil when it has none.
    func narrowed(to format: ReleaseFormat) -> Release? {
        let kept = editions.filter { $0.format == format }
        guard !kept.isEmpty else { return nil }
        let next = kept.filter(\.isUpcoming).compactMap(\.date)
            .min { ReleaseDateText.lastDay($0) < ReleaseDateText.lastDay($1) }
        return Release(
            key: key, isSeries: isSeries, seriesId: seriesId, language: language, readIn: readIn,
            title: title, author: author, coverURL: coverURL, nextDate: next, editions: kept,
            series: series
        )
    }

    /// One edition drawn as a book of the library: its own title and cover,
    /// its place in the saga, in the edition's language.
    func book(_ edition: ReleaseEdition) -> Book {
        Book(
            id: "\(key)-\(edition.id)",
            title: edition.title,
            authors: author.map { [$0] } ?? [],
            format: edition.format == .audiobook ? .audiobook : .book,
            isbn13: edition.isbn13,
            language: language,
            series: seriesId.map { id in
                SeriesMembership(
                    id: id,
                    name: series?.name ?? title,
                    volume: edition.volume,
                    kind: .main
                )
            },
            coverURL: edition.coverURL ?? (edition.volume == nil ? coverURL : nil),
            status: .toRead
        )
    }
}

struct DiscoverFeed: Sendable {
    var preparedAt: Date?
    var canRefresh: Bool
    var upcoming: [Release]
    var maybe: [Release]

    var isEmpty: Bool { upcoming.isEmpty && maybe.isEmpty }

    /// The tab through one format: a work stays in "À venir" only for an
    /// edition of that format still to come, the soonest first.
    func narrowed(to format: ReleaseFormat) -> DiscoverFeed {
        let coming = upcoming.compactMap { $0.narrowed(to: format) }
        return DiscoverFeed(
            preparedAt: preparedAt,
            canRefresh: canRefresh,
            upcoming: coming.filter { $0.nextDate != nil }.sorted {
                ReleaseDateText.lastDay($0.nextDate ?? "") < ReleaseDateText.lastDay($1.nextDate ?? "")
            },
            maybe: maybe.compactMap { $0.narrowed(to: format) }
                + coming.filter { $0.nextDate == nil && $0.language != $0.readIn }
        )
    }

    mutating func remove(key: String) {
        upcoming.removeAll { $0.key == key }
        maybe.removeAll { $0.key == key }
    }
}

enum DiscoverAPI {
    /// A look runs one web-searching model call per work: the request is given
    /// the server's whole ceiling plus a margin.
    private static let refreshTimeout: TimeInterval = 200
    /// Building a book nobody opened before is a grounded model call.
    private static let previewTimeout: TimeInterval = 120

    static func feed() async throws -> DiscoverFeed {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.DiscoverQuery()
        )
        return DiscoverFeed(fields: data.discover.fragments.discoverFields)
    }

    static func refresh() async throws -> DiscoverFeed {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.RefreshDiscoverMutation(),
            requestTimeout: refreshTimeout,
            changesLibrary: false
        )
        return DiscoverFeed(fields: data.refreshDiscover.fragments.discoverFields)
    }

    /// "Pas intéressé": the work never comes back in that language, nor its
    /// alerts.
    static func dismiss(key: String) async throws {
        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.DismissReleaseMutation(key: key),
            changesLibrary: false
        )
    }

    /// A book of the tab the reader does not hold, built whole. Nil when it
    /// could not be.
    static func preview(releaseKey: String, title: String) async throws -> ScannedBook? {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.BookPreviewQuery(releaseKey: releaseKey, title: title),
            requestTimeout: previewTimeout
        )
        return data.bookPreview.map { ScannedBook(fields: $0.fragments.scannedRecord) }
    }
}

private extension DiscoverFeed {
    init(fields: ShioriGraphQL.DiscoverFields) {
        self.init(
            preparedAt: fields.preparedAt.flatMap(GraphQLHelpers.parseISO8601),
            canRefresh: fields.canRefresh,
            upcoming: fields.upcoming.compactMap { Release(fields: $0.fragments.releaseFields) },
            maybe: fields.maybe.compactMap { Release(fields: $0.fragments.releaseFields) }
        )
    }
}

private extension Release {
    init?(fields: ShioriGraphQL.ReleaseFields) {
        guard let language = fields.language.value?.asDomain,
              let readIn = fields.readIn.value?.asDomain else { return nil }
        self.init(
            key: fields.key,
            isSeries: fields.kind.value == .series,
            seriesId: fields.seriesId,
            language: language,
            readIn: readIn,
            title: fields.title,
            author: fields.author,
            coverURL: fields.coverUrl.flatMap(URL.init(string:)),
            nextDate: fields.nextDate,
            editions: fields.editions.map { edition in
                ReleaseEdition(
                    title: edition.title,
                    volume: edition.volume,
                    format: edition.format.value == .audiobook ? .audiobook : .book,
                    date: edition.date,
                    isbn13: edition.isbn13,
                    coverURL: edition.coverUrl.flatMap(URL.init(string:)),
                    audibleURL: edition.audibleUrl.flatMap(URL.init(string:))
                )
            },
            series: fields.series.map { series in
                SeriesAPI.followedRow(
                    series.fragments.followedSeriesRow,
                    volumes: series.volumes.map(\.fragments.followedVolume),
                    spine: series.catalogue?.spine.map(\.fragments.volumeEntry)
                )
            }
        )
    }
}
