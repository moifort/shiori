import Foundation

/// Everything the release, award and suggestion pages ask of the server, as closures:
/// `.live` goes through the domain's APIs, `.preview` answers from the
/// fixtures, and a test builds the one it needs inline.
struct DiscoverClient: Sendable {
    var discovery: @Sendable (ReleaseFormat) async throws -> DiscoveryPage
    var awaited: @Sendable (ReleaseFormat) async throws -> [AwaitedEdition]
    var stopAwaiting: @Sendable (_ editionId: String) async throws -> Void
    /// Awaits a book not in the library, and answers with the edition the
    /// server now watches.
    var awaitEdition: @Sendable (BookDraft, ReleaseFormat) async throws -> AwaitedEdition
    var dismissSuggestion: @Sendable (_ id: String, DismissalReason) async throws -> Void
    /// The release a list showed, described for its page by the server.
    var describe: @Sendable (ReleaseItem) async throws -> Release
    /// Onto the pile, through the one "look up, then add" use case.
    var addBook: @Sendable (BookDraft) async throws -> Void
    /// A suggestion put on the shelf from its page: the book's id.
    var addSuggestion: @Sendable (BookDraft) async throws -> String = { _ in "" }
    /// Onto the wishlist, with where it was seen and what labels it.
    var wish: @Sendable (BookDraft, Wish.Origin, _ label: String?) async throws -> Void = { _, _, _ in }
    /// A book said read by mistake from its suggestion, off the shelf again.
    var deleteBook: @Sendable (_ id: String) async throws -> Void = { _ in }
    /// A dismissal taken back from the red thumb.
    var reconsiderSuggestion: @Sendable (_ id: String) async throws -> Void = { _ in }
    /// An award winner turned down, the novel in every format.
    var dismissWinner: @Sendable (_ key: String) async throws -> Void = { _ in }
    /// The same taken back from the red thumb.
    var reconsiderWinner: @Sendable (_ key: String) async throws -> Void = { _ in }
    /// A saga's recording through the reader's Audible account.
    var addAudibleVolume: @Sendable (_ seriesId: String, _ volume: Int) async throws -> Void
    /// Whether nothing can reach the reader: the system said no, or every
    /// alert is off.
    var alertsSilenced: @Sendable () async -> Bool
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
        awaited: { try await AwaitedAPI.awaited(format: $0) },
        stopAwaiting: { try await AwaitedAPI.stop(id: $0) },
        awaitEdition: { try await AwaitedAPI.awaitScanned($0, format: $1) },
        dismissSuggestion: { try await SuggestionsAPI.dismiss(id: $0, reason: $1) },
        describe: { try await ReleaseAPI.describe($0) },
        addBook: { _ = try await BookAddition.add($0, source: .discover) },
        addSuggestion: { try await BookAddition.add($0, source: .discover).id },
        wish: { try await WishlistAPI.wish($0, origin: $1, label: $2) },
        deleteBook: { try await BookAPI.delete(id: $0) },
        reconsiderSuggestion: { try await SuggestionsAPI.reconsider(id: $0) },
        dismissWinner: { try await AwardsAPI.dismiss(key: $0) },
        reconsiderWinner: { try await AwardsAPI.reconsider(key: $0) },
        addAudibleVolume: { seriesId, volume in
            _ = try await SeriesAPI.addAudibleVolume(seriesId: seriesId, volume: volume)
            track(.bookAdded(source: .discover))
        },
        alertsSilenced: {
            let denied = await PushRegistrar.shared.authorizationStatus() == .denied
            let settings = try? await NotificationsAPI.settings()
            return denied || (settings?.enabled.isEmpty ?? false)
        },
        sagaVolumes: { try await BookAPI.sagaVolumes(seriesId: $0, language: $1) },
        setSagaFollowed: { _ = try await SeriesAPI.setFollowed(seriesId: $0, followed: $1) },
        book: { try await BookAPI.book(id: $0) }
    )

    static let preview = DiscoverClient(
        discovery: { DiscoveryFeed.preview.page($0) },
        awaited: { DiscoveryFeed.preview.awaited[$0] ?? [] },
        stopAwaiting: { _ in },
        awaitEdition: { draft, format in .pending(format: format, of: draft) },
        dismissSuggestion: { _, _ in },
        describe: { _ in .preview },
        addBook: { _ in },
        addAudibleVolume: { _, _ in },
        alertsSilenced: { false }
    )
}
