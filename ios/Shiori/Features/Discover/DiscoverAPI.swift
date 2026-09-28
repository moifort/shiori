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

    var graphQL: ShioriGraphQL.ReleaseFormat {
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

/// A work of an author the reader does not hold, announced or just out,
/// outside the sagas they hold, as the weekly web search found it.
struct DiscoveredWork: Identifiable, Hashable, Codable, Sendable {
    let title: String
    /// `YYYY`, `YYYY-MM` or `YYYY-MM-DD`.
    let date: String?
    let isbn13: String?
    let coverURL: URL?
    /// The recording's page on the reader's Audible store. Nil on a printed
    /// work, on a recording Audible never confirmed, and without an Audible
    /// account.
    var audibleURL: URL?
    /// The new saga it opens, when it is a volume of one.
    let seriesName: String?
    let volume: Int?

    var id: String { title }
}

/// What one author has for the reader in one format, outside the sagas they
/// hold: the author page's "Prochaines sorties" and "Nouveautés".
struct AuthorReleases: Codable, Sendable {
    /// The soonest work announced.
    var next: DiscoveredWork?
    /// The works out in the last three months, the newest first.
    var recent: [DiscoveredWork] = []

    var isEmpty: Bool { next == nil && recent.isEmpty }
}

/// One row of the Authors shelf: an author the reader holds, drawn as the
/// Library's Authors shelf draws them, and what they have for the reader.
struct AuthorDiscovery: Identifiable, Codable, Sendable {
    let author: FollowedAuthor
    /// The soonest work announced.
    let next: DiscoveredWork?
    /// The works out in the last three months, the newest first.
    let recent: [DiscoveredWork]

    var id: String { author.id }
}

/// One volume of a saga, announced or just out, as the Books shelf lists it
/// and its page opens.
struct DiscoveryVolume: Identifiable, Codable, Sendable {
    let saga: SagaDiscovery
    let volume: DiscoveredVolume

    var id: String { "\(saga.id)-\(volume.number)" }
}

/// The tab as last shown, one list per format.
struct DiscoveryFeed: Codable, Sendable {
    var rows: [ReleaseFormat: [SagaDiscovery]] = [:]
    var authors: [ReleaseFormat: [AuthorDiscovery]] = [:]
    /// How many sagas and authors the reader follows in each format.
    var followed: [ReleaseFormat: Int] = [:]
    /// "Coups de cœur de vos amis", whatever the format.
    var picks = FriendPicks()
    /// The editions awaited in each format, the ones out first.
    var awaited: [ReleaseFormat: [AwaitedEdition]] = [:]
}

/// The tab in one format, and how many of its sagas and authors were never
/// looked up.
struct DiscoveryPage: Sendable {
    let rows: [SagaDiscovery]
    let authors: [AuthorDiscovery]
    let unwatched: Int
    /// How many sagas and authors the reader follows in that format.
    let followed: Int
}

enum DiscoverAPI {
    /// A first look runs grounded model calls, a few side by side, for up to a
    /// minute and a half: the request is given that and a margin.
    private static let lookUpTimeout: TimeInterval = 150

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

    /// What the author page shows under its heading, in each format: read off
    /// the weekly watches, so it answers at once.
    static func authorReleases(key: String) async throws -> [ReleaseFormat: AuthorReleases] {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.AuthorReleasesQuery(key: key)
        )
        return [
            .book: AuthorReleases(fields: data.book.fragments.authorReleasesFields),
            .audiobook: AuthorReleases(fields: data.audiobook.fragments.authorReleasesFields),
        ]
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
            authors: fields.authors.map { row in
                AuthorDiscovery(
                    author: FollowedAuthor(row: row.author.fragments.followedAuthorRow),
                    next: row.next.map { DiscoveredWork(fields: $0.fragments.discoveredWorkFields) },
                    recent: row.recent.map { DiscoveredWork(fields: $0.fragments.discoveredWorkFields) }
                )
            },
            unwatched: fields.unwatched,
            followed: fields.followed
        )
    }
}

private extension AuthorReleases {
    init(fields: ShioriGraphQL.AuthorReleasesFields) {
        self.init(
            next: fields.next.map { DiscoveredWork(fields: $0.fragments.discoveredWorkFields) },
            recent: fields.recent.map { DiscoveredWork(fields: $0.fragments.discoveredWorkFields) }
        )
    }
}

private extension DiscoveredWork {
    init(fields: ShioriGraphQL.DiscoveredWorkFields) {
        self.init(
            title: fields.title,
            date: fields.date,
            isbn13: fields.isbn13,
            coverURL: fields.coverUrl.flatMap(URL.init(string:)),
            audibleURL: fields.audibleUrl.flatMap(URL.init(string:)),
            seriesName: fields.seriesName,
            volume: fields.volume
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
