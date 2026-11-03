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
    /// A friend's book onto the reader's pile, in the format they take it in.
    var takeFriendBook: @Sendable (_ friendId: String, _ bookId: String, BookFormat) async throws -> Void
    /// A narrator's recording onto the pile.
    var addRecording: @Sendable (NarratorNews) async throws -> Void
    /// Whether nothing can reach the reader: the bell is struck through.
    var alertsSilenced: @Sendable () async -> Bool
    /// An invitation to pass on, from the empty Amis tab and its rail.
    var invite: @Sendable () async throws -> FriendInvitation
}

extension NewsClient {
    static let live = NewsClient(
        feed: { try await NewsAPI.feed(after: $0, limit: $1) },
        upcoming: { try await NewsAPI.upcoming() },
        yearReleases: { try await NewsAPI.yearReleases() },
        narratorNews: { try await NewsAPI.narratorNews() },
        takeFriendBook: { friendId, bookId, format in
            _ = try await FriendsAPI.addBook(friendId: friendId, bookId: bookId, status: .toRead, format: format)
        },
        addRecording: { news in
            var draft = BookDraft(title: news.title, authors: news.authors)
            draft.format = .audiobook
            draft.media = []
            draft.status = .toRead
            _ = try await BookAddition.add(draft, source: .discover)
        },
        alertsSilenced: { await DiscoverClient.live.alertsSilenced() },
        invite: { try await FriendsAPI.invite() }
    )

    static let preview = NewsClient(
        feed: { after, limit in
            CursorPage(FeedEvent.previews, limit: limit, after: after, cursor: \.id)
        },
        upcoming: { UpcomingRelease.previews },
        yearReleases: { UpcomingRelease.previews },
        narratorNews: { [.preview] },
        takeFriendBook: { _, _, _ in },
        addRecording: { _ in },
        alertsSilenced: { false },
        invite: { .preview }
    )
}
