import Foundation

/// The saga read or the saga heard: the filter the tab is read through, kept
/// between visits.
enum ReleaseFormat: String, Codable, Sendable, Hashable, CaseIterable, Identifiable {
    case book, audiobook
    var id: String { rawValue }

    var filterLabel: String {
        switch self {
        case .book: String(localized: "Livres")
        case .audiobook: String(localized: "Livres audio")
        }
    }

    var symbol: String {
        switch self {
        case .book: "book"
        case .audiobook: "headphones"
        }
    }

    fileprivate var graphQL: ShioriGraphQL.ReleaseFormat {
        switch self {
        case .book: .book
        case .audiobook: .audiobook
        }
    }
}

/// A volume of a saga the reader does not hold, announced, as the weekly web
/// search found it.
struct DiscoveredVolume: Identifiable, Hashable, Codable, Sendable {
    let number: Int
    let title: String
    /// `YYYY`, `YYYY-MM` or `YYYY-MM-DD`. Nil for a volume announced for a date
    /// nobody found.
    let date: String?
    let isbn13: String?
    let coverURL: URL?
    /// The recording's page on the reader's Audible store, which the Audible
    /// app opens on the title. Nil on a saga read, on a recording Audible never
    /// confirmed, and without an Audible account.
    var audibleURL: URL?

    var id: Int { number }
}

/// What one saga has for the reader: the next volume announced they do not
/// hold. The volumes out are the saga screen's own, read off its catalogue.
struct SagaReleases: Codable, Sendable, Equatable {
    /// Whether the saga was ever looked up in that language: until it is, the
    /// saga screen asks for it.
    var watched: Bool
    var next: DiscoveredVolume?
}

/// One row of the tab: a saga the reader follows, drawn as the Series tab
/// draws it, and what it has for them.
struct SagaDiscovery: Identifiable, Codable, Sendable {
    var series: FollowedSeries
    let releases: SagaReleases
    /// The numbers of the volumes out the reader has not added yet, in order.
    var missing: [Int] = []
    /// The volumes out in the last week the reader can have now, the newest
    /// first.
    var recent: [DiscoveredVolume] = []

    var id: String { series.id }
}

/// One volume of a saga, announced or just out, as the Books shelf lists it
/// and its page opens.
struct DiscoveryVolume: Identifiable {
    let saga: SagaDiscovery
    let volume: DiscoveredVolume

    var id: String { "\(saga.id)-\(volume.number)" }
}

/// The tab as last shown, one list per format.
struct DiscoveryFeed: Codable, Sendable {
    var rows: [ReleaseFormat: [SagaDiscovery]] = [:]
    /// How many sagas the reader follows in each format.
    var followed: [ReleaseFormat: Int] = [:]
}

/// The tab in one format, and how many of its sagas were never looked up.
struct DiscoveryPage: Sendable {
    let rows: [SagaDiscovery]
    let unwatched: Int
    /// How many sagas the reader follows in that format.
    let followed: Int
}

/// A volume announced, described for its page before the reader adds it: the
/// record a scan would propose, placed in its saga and edition, with what only
/// a recording has.
struct AnnouncedVolumePreview {
    let book: ScannedBook
    let narrators: [String]
    let durationMinutes: Int?
    /// `YYYY`, `YYYY-MM` or `YYYY-MM-DD`.
    let releaseDate: String?
    let audibleURL: URL?
}

enum DiscoverAPI {
    /// A first look runs grounded model calls, a few side by side, for up to a
    /// minute and a half: the request is given that and a margin.
    private static let lookUpTimeout: TimeInterval = 150
    /// A preview is a scan's grounded step: given what a scan is given.
    private static let previewTimeout: TimeInterval = 190

    static func discovery(format: ReleaseFormat) async throws -> DiscoveryPage {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.DiscoveryQuery(format: .case(format.graphQL))
        )
        return DiscoveryPage(fields: data.discovery.fragments.discoveryFields)
    }

    /// Look up now the sagas of that format nobody ever looked up. What was
    /// found is written into the sagas' catalogues, so the Series tab and the
    /// dashboard are told, and draw the same volumes as here.
    static func lookUp(format: ReleaseFormat) async throws -> DiscoveryPage {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.LookUpDiscoveryMutation(format: .case(format.graphQL)),
            requestTimeout: lookUpTimeout
        )
        return DiscoveryPage(fields: data.lookUpDiscovery.fragments.discoveryFields)
    }

    /// Describes a volume announced for its page. Spends one scan: throws
    /// `APIError.domain(code: "QUOTA_EXHAUSTED")` once nothing is left.
    static func preview(
        seriesId: String,
        language: BookLanguage,
        number: Int
    ) async throws -> AnnouncedVolumePreview {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.PreviewAnnouncedVolumeMutation(
                seriesId: seriesId,
                language: LibraryAPI.graphQLLanguage(language),
                number: number
            ),
            requestTimeout: previewTimeout,
            // A page to look at: nothing reaches the library before `addBook`.
            changesLibrary: false
        )
        let preview = data.previewAnnouncedVolume
        return AnnouncedVolumePreview(
            book: ScannedBook(fields: preview.book.fragments.scannedRecord),
            narrators: preview.narrators,
            durationMinutes: preview.durationMinutes,
            releaseDate: preview.releaseDate,
            audibleURL: preview.audibleUrl.flatMap(URL.init(string:))
        )
    }

    /// What the saga screen shows under its introduction, in the edition
    /// opened.
    static func sagaReleases(seriesId: String, language: BookLanguage) async throws -> SagaReleases {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.SagaReleasesQuery(
                seriesId: seriesId,
                language: LibraryAPI.graphQLLanguage(language)
            )
        )
        return SagaReleases(fields: data.sagaReleases.fragments.sagaReleasesFields)
    }

    /// The same, the saga looked up on the web first when nobody ever did —
    /// which writes into its catalogue, so its row is asked again.
    static func lookUpSaga(seriesId: String, language: BookLanguage) async throws -> SagaReleases {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            concerning: .series(id: seriesId),
            mutation: ShioriGraphQL.LookUpSagaReleasesMutation(
                seriesId: seriesId,
                language: LibraryAPI.graphQLLanguage(language)
            ),
            requestTimeout: lookUpTimeout
        )
        return SagaReleases(fields: data.lookUpSagaReleases.fragments.sagaReleasesFields)
    }
}

private extension DiscoveryPage {
    init(fields: ShioriGraphQL.DiscoveryFields) {
        self.init(
            rows: fields.sagas.map { row in
                SagaDiscovery(
                    series: SeriesAPI.followedRow(
                        row.series.fragments.followedSeriesRow,
                        volumes: row.series.volumes.map(\.fragments.followedVolume),
                        spine: row.series.catalogue?.spine.map(\.fragments.volumeEntry)
                    ),
                    releases: SagaReleases(
                        watched: true,
                        next: row.next.map { DiscoveredVolume(fields: $0.fragments.discoveredVolumeFields) }
                    ),
                    missing: row.missing,
                    recent: row.recent.map { DiscoveredVolume(fields: $0.fragments.discoveredVolumeFields) }
                )
            },
            unwatched: fields.unwatched,
            followed: fields.followed
        )
    }
}

private extension SagaReleases {
    init(fields: ShioriGraphQL.SagaReleasesFields) {
        self.init(
            watched: fields.watched,
            next: fields.next.map { DiscoveredVolume(fields: $0.fragments.discoveredVolumeFields) }
        )
    }
}

private extension DiscoveredVolume {
    init(fields: ShioriGraphQL.DiscoveredVolumeFields) {
        self.init(
            number: fields.number,
            title: fields.title,
            date: fields.date,
            isbn13: fields.isbn13,
            coverURL: fields.coverUrl.flatMap(URL.init(string:)),
            audibleURL: fields.audibleUrl.flatMap(URL.init(string:))
        )
    }
}

/// What each saga screen last showed of its releases, for the session: a saga
/// opened again draws its section at once.
@MainActor
enum SagaReleasesCache {
    static var entries: [String: SagaReleases] = [:]
}
