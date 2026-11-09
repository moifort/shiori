import Foundation

/// Everything the Actualités tab asks of the server, as closures: `.live` goes
/// through the domain's APIs and the existing add-a-book use cases, `.preview`
/// answers from the fixtures, and a test builds the one it needs inline.
struct NewsClient: Sendable {
    var feed: @Sendable (_ after: String?, _ limit: Int) async throws -> CursorPage<FeedEvent>
    var upcoming: @Sendable () async throws -> [UpcomingRelease]
    /// What came out since the start of the year, which "Sorti" draws from.
    var yearReleases: @Sendable () async throws -> [UpcomingRelease]
    var narratorNews: @Sendable () async throws -> [NarratorNews]
    /// A friend's book onto the reader's pile or among the books read, in the
    /// format they take it in.
    var addFriendBook: @Sendable (_ friendId: String, _ bookId: String, CopiedStatus, BookFormat) async throws -> Void
    var wishFriendBook: @Sendable (_ friendId: String, _ bookId: String) async throws -> Void
    /// The friend's book's edition awaited in the app's language.
    var awaitFriendBook: @Sendable (_ friendId: String, _ bookId: String, ReleaseFormat) async throws -> Void
    /// A book out lately onto the shelf, as its row describes it.
    var addReleased: @Sendable (BookDraft) async throws -> Void
    var wishReleased: @Sendable (BookDraft) async throws -> Void
    var awaitReleased: @Sendable (BookDraft, ReleaseFormat) async throws -> Void
    /// Whether nothing can reach the reader: the bell is struck through.
    var alertsSilenced: @Sendable () async -> Bool
    /// An invitation to pass on, from the empty Amis tab and its rail.
    var invite: @Sendable () async throws -> FriendInvitation
    /// The prizes' winners in print, as Découvrir lists them.
    var awards: @Sendable () async throws -> [AwardSection] = { [] }
    /// The month's discoveries already chosen: read, never asked for, so
    /// opening the tab never sets the model to work.
    var discoveries: @Sendable () async throws -> [Suggestion] = { [] }
    /// A discovery or a prize onto the wish list.
    var wishDiscovery: @Sendable (BookDraft, Wish.Origin) async throws -> Void = { _, _ in }
    /// "Pas intéressé" on the month's discovery.
    var dismissSuggestion: @Sendable (_ id: String) async throws -> Void = { _ in }
    /// "Pas intéressé" on a prize's winner.
    var dismissWinner: @Sendable (_ key: String) async throws -> Void = { _ in }
}

extension NewsClient {
    static let live = NewsClient(
        feed: { try await NewsAPI.feed(after: $0, limit: $1) },
        upcoming: { try await NewsAPI.upcoming() },
        yearReleases: { try await NewsAPI.yearReleases() },
        narratorNews: { try await NewsAPI.narratorNews() },
        addFriendBook: { friendId, bookId, status, format in
            _ = try await FriendsAPI.addBook(friendId: friendId, bookId: bookId, status: status, format: format)
        },
        wishFriendBook: { friendId, bookId in
            _ = try await WishlistAPI.wish(friendId: friendId, bookId: bookId)
        },
        awaitFriendBook: { friendId, bookId, format in
            _ = try await AwaitedAPI.awaitEdition(friendId: friendId, bookId: bookId, format: format)
        },
        addReleased: { draft in _ = try await BookAddition.add(draft, source: .discover) },
        wishReleased: { draft in _ = try await WishlistAPI.wish(draft, origin: .discovery) },
        awaitReleased: { draft, format in _ = try await AwaitedAPI.awaitScanned(draft, format: format) },
        alertsSilenced: { await DiscoverClient.live.alertsSilenced() },
        invite: { try await FriendsAPI.invite() },
        awards: { try await AwardsAPI.sections(format: .book) },
        discoveries: { try await SuggestionsAPI.monthly(format: .book, lookUp: false).suggestions },
        wishDiscovery: { draft, origin in _ = try await WishlistAPI.wish(draft, origin: origin) },
        dismissSuggestion: { try await SuggestionsAPI.dismiss(id: $0, reason: .notInterested) },
        dismissWinner: { try await AwardsAPI.dismiss(key: $0) }
    )

    static let preview = NewsClient(
        feed: { after, limit in
            CursorPage(FeedEvent.previews, limit: limit, after: after, cursor: \.id)
        },
        upcoming: { UpcomingRelease.previews },
        yearReleases: { UpcomingRelease.previews },
        narratorNews: { [.preview] },
        addFriendBook: { _, _, _, _ in },
        wishFriendBook: { _, _ in },
        awaitFriendBook: { _, _, _ in },
        addReleased: { _ in },
        wishReleased: { _ in },
        awaitReleased: { _, _ in },
        alertsSilenced: { false },
        invite: { .preview },
        awards: { AwardSection.previews },
        discoveries: { MonthlyDiscoveries.preview.suggestions }
    )
}
