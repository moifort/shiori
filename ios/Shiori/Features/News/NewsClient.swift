import Foundation

/// Everything the Actualités tab asks of the server, as closures: `.live` goes
/// through the domain's APIs and the existing add-a-book use cases, `.preview`
/// answers from the fixtures, and a test builds the one it needs inline.
struct NewsClient: Sendable {
    var feed: @Sendable (_ after: String?, _ limit: Int) async throws -> CursorPage<FeedEvent>
    var upcoming: @Sendable () async throws -> [UpcomingRelease]
    var narratorNews: @Sendable () async throws -> [NarratorNews]
    /// The latest novel an award crowned, for the feed's award card.
    var latestWinner: @Sendable () async throws -> AwardWinner?
    /// A friend's book onto the reader's pile, in the format they take it in.
    var takeFriendBook: @Sendable (_ friendId: String, _ bookId: String, BookFormat) async throws -> Void
    /// An award winner onto the pile.
    var addWinner: @Sendable (AwardWinner) async throws -> Void
    /// A narrator's recording onto the pile.
    var addRecording: @Sendable (NarratorNews) async throws -> Void
    /// Whether nothing can reach the reader: the bell is struck through.
    var alertsSilenced: @Sendable () async -> Bool
}

extension NewsClient {
    static let live = NewsClient(
        feed: { try await NewsAPI.feed(after: $0, limit: $1) },
        upcoming: { try await NewsAPI.upcoming() },
        narratorNews: { try await NewsAPI.narratorNews() },
        latestWinner: {
            try await AwardsAPI.sections(format: .book).first?.winners.first
        },
        takeFriendBook: { friendId, bookId, format in
            _ = try await FriendsAPI.addBook(friendId: friendId, bookId: bookId, status: .toRead, format: format)
        },
        addWinner: { _ = try await BookAddition.add($0.pileDraft, source: .discover) },
        addRecording: { news in
            var draft = BookDraft(title: news.title, authors: news.authors)
            draft.format = .audiobook
            draft.media = []
            draft.status = .toRead
            _ = try await BookAddition.add(draft, source: .discover)
        },
        alertsSilenced: { await DiscoverClient.live.alertsSilenced() }
    )

    static let preview = NewsClient(
        feed: { after, limit in
            CursorPage(FeedEvent.previews, limit: limit, after: after, cursor: \.id)
        },
        upcoming: { UpcomingRelease.previews },
        narratorNews: { [.preview] },
        latestWinner: { .preview },
        takeFriendBook: { _, _, _ in },
        addWinner: { _ in },
        addRecording: { _ in },
        alertsSilenced: { false }
    )
}
