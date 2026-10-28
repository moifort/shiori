import Foundation

/// Everything the Home tab asks of the server, as closures: `.live` goes
/// through the APIs, `.preview` answers from the fixtures, and a test builds
/// the one it needs inline.
struct HomeClient: Sendable {
    var dashboard: @Sendable () async throws -> Dashboard
    /// The month's discoveries, read as they stand.
    var discoveries: @Sendable () async throws -> MonthlyDiscoveries
    /// The month's discoveries, made when the month has none yet: the home
    /// asks once the shelf has books and the month's are missing, and asks
    /// again while they are being made.
    var lookUpDiscoveries: @Sendable () async throws -> MonthlyDiscoveries
    var discovery: @Sendable (ReleaseFormat) async throws -> DiscoveryPage
    var awaited: @Sendable (ReleaseFormat) async throws -> [AwaitedEdition]
    var dismissSuggestion: @Sendable (_ id: String, DismissalReason) async throws -> Void
    var stopAwaiting: @Sendable (_ editionId: String) async throws -> Void
    /// A dismissal taken back from the carousel's red thumb.
    var reconsiderSuggestion: @Sendable (_ id: String) async throws -> Void = { _ in }
    var genreInsights: @Sendable () async throws -> GenreInsights
    /// The book read now, finished from its card.
    var finish: @Sendable (_ bookId: String) async throws -> Void = { _ in }
    /// The book read now, its page recorded from its card, then moved on when
    /// the reader marked it read or gave it up in the same sheet.
    var recordPage: @Sendable (_ bookId: String, _ page: Int?, ReadingStatus?) async throws -> Void = { _, _, _ in }
    /// The book read now, rated from its card: which marks it read.
    var rate: @Sendable (_ bookId: String, _ stars: Double) async throws -> Void = { _, _ in }
}

extension HomeClient {
    static let live = HomeClient(
        dashboard: { try await HomeAPI.dashboard() },
        discoveries: { try await SuggestionsAPI.monthly(format: .book, lookUp: false) },
        lookUpDiscoveries: { try await SuggestionsAPI.monthly(format: .book, lookUp: true) },
        discovery: { try await DiscoverAPI.discovery(format: $0) },
        awaited: { try await AwaitedAPI.awaited(format: $0) },
        dismissSuggestion: { try await SuggestionsAPI.dismiss(id: $0, reason: $1) },
        stopAwaiting: { try await AwaitedAPI.stop(id: $0) },
        reconsiderSuggestion: { try await SuggestionsAPI.reconsider(id: $0) },
        genreInsights: { try await HomeAPI.genreInsights() },
        finish: { _ = try await BookAPI.setStatus(id: $0, status: .read) },
        recordPage: { id, page, status in
            if let page { _ = try await BookAPI.recordPage(id: id, page: page) }
            if let status { _ = try await BookAPI.setStatus(id: id, status: status) }
        },
        rate: { _ = try await BookAPI.rate(id: $0, stars: $1) }
    )
}

extension HomeClient {
    /// Answers from the fixtures: the dashboard, one saga with a volume
    /// announced, and the month's discoveries.
    static let preview = HomeClient(
        dashboard: { .preview },
        discoveries: { .preview },
        lookUpDiscoveries: { .preview },
        discovery: { format in
            DiscoveryPage(rows: format == .book ? [.preview] : [], authors: [], unwatched: 0, followed: 1)
        },
        awaited: { _ in [] },
        dismissSuggestion: { _, _ in },
        stopAwaiting: { _ in },
        genreInsights: { .preview }
    )
}
