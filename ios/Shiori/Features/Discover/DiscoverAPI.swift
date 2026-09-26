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

/// Where the reader goes to get a volume.
enum Store: String, Codable, Sendable, Hashable {
    case amazon, audible

    /// The button's words: where the tap leads.
    var actionLabel: String {
        switch self {
        case .amazon: String(localized: "Amazon")
        case .audible: String(localized: "Audible")
        }
    }
}

/// A volume of a saga the reader does not hold, out or announced, as the
/// weekly web search found it.
struct DiscoveredVolume: Identifiable, Hashable, Codable, Sendable {
    let number: Int
    let title: String
    /// `YYYY`, `YYYY-MM` or `YYYY-MM-DD`. Nil for a volume out on a date
    /// nobody found.
    let date: String?
    let isbn13: String?
    let coverURL: URL?
    let store: Store
    let storeURL: URL

    var id: Int { number }
}

/// What one saga has for the reader: the volumes out they do not hold, and the
/// next one announced.
struct SagaReleases: Codable, Sendable, Equatable {
    var available: [DiscoveredVolume]
    var next: DiscoveredVolume?

    var isEmpty: Bool { available.isEmpty && next == nil }
}

/// One row of the tab: a saga the reader follows, drawn as the Series tab
/// draws it, and what it has for them.
struct SagaDiscovery: Identifiable, Codable, Sendable {
    var series: FollowedSeries
    let releases: SagaReleases

    var id: String { series.id }

    /// The row's cover strip, narrowed to what matters here: the last volume
    /// the reader holds, to say where they stand; the volumes out they lack,
    /// in full; the next one announced, with its date.
    var strip: [SeriesStripItem] {
        let held = series.volumes.last.map { [SeriesStripItem.owned($0)] } ?? []
        let out = releases.available.map { volume in
            SeriesStripItem.missing(
                key: "\(series.id)-\(volume.number)",
                number: volume.number,
                title: volume.title,
                forthcoming: false,
                coverURL: volume.coverURL
            )
        }
        let announced = releases.next.map { volume in
            [SeriesStripItem.missing(
                key: "\(series.id)-\(volume.number)",
                number: volume.number,
                title: volume.title,
                forthcoming: true,
                date: volume.date,
                coverURL: volume.coverURL
            )]
        } ?? []
        return held + out + announced
    }
}

/// The tab as last shown, one list per format.
struct DiscoveryFeed: Codable, Sendable {
    var rows: [ReleaseFormat: [SagaDiscovery]] = [:]
}

enum DiscoverAPI {
    static func discovery(format: ReleaseFormat) async throws -> [SagaDiscovery] {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.DiscoveryQuery(format: .case(format.graphQL))
        )
        return data.discovery.map { row in
            SagaDiscovery(
                series: SeriesAPI.followedRow(
                    row.series.fragments.followedSeriesRow,
                    volumes: row.series.volumes.map(\.fragments.followedVolume),
                    spine: nil
                ),
                releases: SagaReleases(
                    available: row.available.compactMap { DiscoveredVolume(fields: $0.fragments.discoveredVolumeFields) },
                    next: row.next.flatMap { DiscoveredVolume(fields: $0.fragments.discoveredVolumeFields) }
                )
            )
        }
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
        return SagaReleases(
            available: data.sagaReleases.available.compactMap {
                DiscoveredVolume(fields: $0.fragments.discoveredVolumeFields)
            },
            next: data.sagaReleases.next.flatMap {
                DiscoveredVolume(fields: $0.fragments.discoveredVolumeFields)
            }
        )
    }
}

private extension DiscoveredVolume {
    init?(fields: ShioriGraphQL.DiscoveredVolumeFields) {
        guard let storeURL = URL(string: fields.storeUrl) else { return nil }
        self.init(
            number: fields.number,
            title: fields.title,
            date: fields.date,
            isbn13: fields.isbn13,
            coverURL: fields.coverUrl.flatMap(URL.init(string:)),
            store: fields.store.value == .audible ? .audible : .amazon,
            storeURL: storeURL
        )
    }
}

/// What each saga screen last showed of its releases, for the session: a saga
/// opened again draws its section at once.
@MainActor
enum SagaReleasesCache {
    static var entries: [String: SagaReleases] = [:]
}
