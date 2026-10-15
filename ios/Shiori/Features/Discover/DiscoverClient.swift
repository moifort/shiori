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
    var awaitEdition: @Sendable (BookDraft, ReleaseFormat) async throws -> Void
    var awards: @Sendable (ReleaseFormat) async throws -> [AwardSection]
    /// The month's discoveries, the selection made when the month has none.
    var discoveries: @Sendable (ReleaseFormat) async throws -> MonthlyDiscoveries
    var dismissSuggestion: @Sendable (_ id: String) async throws -> Void
    var describe: @Sendable (ReleaseSeed) async throws -> ReleaseDescription
    /// Onto the pile, through the one "look up, then add" use case.
    var addBook: @Sendable (BookDraft) async throws -> Void
    /// A saga's recording through the reader's Audible account.
    var addAudibleVolume: @Sendable (_ seriesId: String, _ volume: Int, BookLanguage) async throws -> Void
    /// Whether nothing can reach the reader: the system said no, or every
    /// alert is off.
    var alertsSilenced: @Sendable () async -> Bool
    /// The system's one question about notifications.
    var requestAlerts: @Sendable () async -> Void
}

extension DiscoverClient {
    static let live = DiscoverClient(
        discovery: { try await DiscoverAPI.discovery(format: $0) },
        lookUp: { try await DiscoverAPI.lookUp(format: $0) },
        picks: { try await FriendsAPI.picks() },
        awaited: { try await AwaitedAPI.awaited(format: $0) },
        stopAwaiting: { try await AwaitedAPI.stop(id: $0) },
        awaitEdition: { _ = try await AwaitedAPI.awaitScanned($0, format: $1) },
        awards: { try await AwardsAPI.sections(format: $0) },
        discoveries: { try await SuggestionsAPI.monthly(format: $0, lookUp: true) },
        dismissSuggestion: { try await SuggestionsAPI.dismiss(id: $0) },
        describe: { try await ReleaseAPI.describe($0) },
        addBook: { _ = try await BookAddition.add($0, source: .discover) },
        addAudibleVolume: { seriesId, volume, language in
            _ = try await SeriesAPI.addAudibleVolume(seriesId: seriesId, volume: volume, language: language)
            track(.bookAdded(source: .discover))
        },
        alertsSilenced: {
            let denied = await PushRegistrar.shared.authorizationStatus() == .denied
            let settings = try? await NotificationsAPI.settings()
            return denied || (settings?.enabled.isEmpty ?? false)
        },
        requestAlerts: { _ = await PushRegistrar.shared.requestPermission() }
    )

    static let preview = DiscoverClient(
        discovery: { DiscoveryFeed.preview.page($0) },
        lookUp: { DiscoveryFeed.preview.page($0) },
        picks: { DiscoveryFeed.preview.picks },
        awaited: { DiscoveryFeed.preview.awaited[$0] ?? [] },
        stopAwaiting: { _ in },
        awaitEdition: { _, _ in },
        awards: { _ in AwardSection.previews },
        discoveries: { _ in .preview },
        dismissSuggestion: { _ in },
        describe: { _ in .preview },
        addBook: { _ in },
        addAudibleVolume: { _, _, _ in },
        alertsSilenced: { false },
        requestAlerts: {}
    )
}
