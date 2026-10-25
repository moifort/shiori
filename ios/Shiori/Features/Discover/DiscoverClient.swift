import Foundation

/// Everything Découvrir and the pages it opens ask of the server, as closures:
/// `.live` goes through the domain's APIs, `.preview` answers from the
/// fixtures, and a test builds the one it needs inline.
struct DiscoverClient: Sendable {
    var discovery: @Sendable (ReleaseFormat) async throws -> DiscoveryPage
    /// The first look at a format: everything followed in it looked up on the web.
    var lookUp: @Sendable (ReleaseFormat) async throws -> DiscoveryPage
    var picks: @Sendable () async throws -> FriendPicks
    var awaited: @Sendable (ReleaseFormat) async throws -> [AwaitedEdition]
    var stopAwaiting: @Sendable (_ editionId: String) async throws -> Void
    /// Awaits a book not in the library, and answers with the edition the
    /// server now watches.
    var awaitEdition: @Sendable (BookDraft, ReleaseFormat) async throws -> AwaitedEdition
    var awards: @Sendable (ReleaseFormat) async throws -> [AwardSection]
    /// The month's discoveries, the selection made when the month has none.
    var discoveries: @Sendable (ReleaseFormat) async throws -> MonthlyDiscoveries
    var dismissSuggestion: @Sendable (_ id: String, DismissalReason) async throws -> Void
    var describe: @Sendable (ReleaseSeed) async throws -> ReleaseDescription
    /// Onto the pile, through the one "look up, then add" use case.
    var addBook: @Sendable (BookDraft) async throws -> Void
    /// A saga's recording through the reader's Audible account.
    var addAudibleVolume: @Sendable (_ seriesId: String, _ volume: Int) async throws -> Void
    /// Whether nothing can reach the reader: the system said no, or every
    /// alert is off.
    var alertsSilenced: @Sendable () async -> Bool
    /// The system's one question about notifications.
    var requestAlerts: @Sendable () async -> Void
    /// The volumes of a saga, held or lacking, for the row on a book to
    /// come's page. None by default: a preview that draws no saga leaves it.
    var sagaVolumes: @Sendable (_ seriesId: String, BookLanguage?) async throws -> [SeriesStripItem] = { _, _ in [] }
    /// A saga's alerts on or off: the bell on its volume announced.
    var setSagaFollowed: @Sendable (_ seriesId: String, Bool) async throws -> Void = { _, _ in }
    /// The reader's own copy an edition is awaited of, for its saga.
    var book: @Sendable (_ bookId: String) async throws -> Book? = { _ in nil }
}

extension DiscoverClient {
    static let live = DiscoverClient(
        discovery: { try await DiscoverAPI.discovery(format: $0) },
        lookUp: { try await DiscoverAPI.lookUp(format: $0) },
        picks: { try await FriendsAPI.picks() },
        awaited: { try await AwaitedAPI.awaited(format: $0) },
        stopAwaiting: { try await AwaitedAPI.stop(id: $0) },
        awaitEdition: { try await AwaitedAPI.awaitScanned($0, format: $1) },
        awards: { try await AwardsAPI.sections(format: $0) },
        discoveries: { try await SuggestionsAPI.monthly(format: $0, lookUp: true) },
        dismissSuggestion: { try await SuggestionsAPI.dismiss(id: $0, reason: $1) },
        describe: { try await ReleaseAPI.describe($0) },
        addBook: { _ = try await BookAddition.add($0, source: .discover) },
        addAudibleVolume: { seriesId, volume in
            _ = try await SeriesAPI.addAudibleVolume(seriesId: seriesId, volume: volume)
            track(.bookAdded(source: .discover))
        },
        alertsSilenced: {
            let denied = await PushRegistrar.shared.authorizationStatus() == .denied
            let settings = try? await NotificationsAPI.settings()
            return denied || (settings?.enabled.isEmpty ?? false)
        },
        requestAlerts: { _ = await PushRegistrar.shared.requestPermission() },
        sagaVolumes: { try await BookAPI.sagaVolumes(seriesId: $0, language: $1) },
        setSagaFollowed: { _ = try await SeriesAPI.setFollowed(seriesId: $0, followed: $1) },
        book: { try await BookAPI.book(id: $0) }
    )

    static let preview = DiscoverClient(
        discovery: { DiscoveryFeed.preview.page($0) },
        lookUp: { DiscoveryFeed.preview.page($0) },
        picks: { DiscoveryFeed.preview.picks },
        awaited: { DiscoveryFeed.preview.awaited[$0] ?? [] },
        stopAwaiting: { _ in },
        awaitEdition: { draft, format in .pending(format: format, of: draft) },
        awards: { _ in AwardSection.previews },
        discoveries: { _ in .preview },
        dismissSuggestion: { _, _ in },
        describe: { _ in .preview },
        addBook: { _ in },
        addAudibleVolume: { _, _ in },
        alertsSilenced: { false },
        requestAlerts: {}
    )
}
