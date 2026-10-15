import Foundation

/// Everything the friends' screens ask of the server, as closures: `.live`
/// goes through `FriendsAPI`, `.preview` answers from the fixtures, and a
/// test builds the one it needs inline.
struct FriendsClient: Sendable {
    var friends: @Sendable () async throws -> [Friend]
    var myShelf: @Sendable () async throws -> FriendProfile
    var profile: @Sendable (_ userId: String) async throws -> FriendProfile?
    var libraryPage: @Sendable (_ friendId: String, _ status: ReadingStatus?, _ loved: Bool, _ after: String?)
        async throws -> (books: [FriendBook], hasMore: Bool)
    var sagaPage: @Sendable (_ friendId: String, _ state: SeriesState?, _ loved: Bool, _ after: String?)
        async throws -> (sagas: [FriendSaga], hasMore: Bool)
    var book: @Sendable (_ friendId: String, _ bookId: String) async throws -> FriendBook?
    var audio: @Sendable (_ friendId: String, _ bookId: String) async throws -> AudioAvailability?
    var addBook: @Sendable (_ friendId: String, _ bookId: String, CopiedStatus, BookFormat) async throws -> Void
    var offer: @Sendable (_ friendId: String, _ bookId: String) async throws -> EditionOffer?
    var awaitEdition: @Sendable (_ friendId: String, _ bookId: String, ReleaseFormat) async throws -> AwaitedEdition
    var stopAwaiting: @Sendable (_ editionId: String) async throws -> Void
    var invite: @Sendable () async throws -> FriendInvitation
    var accept: @Sendable (_ code: String) async throws -> Friend
    var remove: @Sendable (_ userId: String) async throws -> Void
}

extension FriendsClient {
    static let live = FriendsClient(
        friends: { try await FriendsAPI.friends() },
        myShelf: { try await FriendsAPI.myShelf() },
        profile: { try await FriendsAPI.profile(userId: $0) },
        libraryPage: { try await FriendsAPI.libraryPage(friendId: $0, status: $1, loved: $2, after: $3) },
        sagaPage: { try await FriendsAPI.sagaPage(friendId: $0, state: $1, loved: $2, after: $3) },
        book: { try await FriendsAPI.book(friendId: $0, bookId: $1) },
        audio: { try await FriendsAPI.audio(friendId: $0, bookId: $1) },
        addBook: { try await FriendsAPI.addBook(friendId: $0, bookId: $1, status: $2, format: $3) },
        offer: { try await AwaitedAPI.offer(friendId: $0, bookId: $1) },
        awaitEdition: { try await AwaitedAPI.awaitEdition(friendId: $0, bookId: $1, format: $2) },
        stopAwaiting: { try await AwaitedAPI.stop(id: $0) },
        invite: { try await FriendsAPI.invite() },
        accept: { try await FriendsAPI.accept(code: $0) },
        remove: { try await FriendsAPI.remove(userId: $0) }
    )

    /// Answers from the fixtures, at once, and accepts every write.
    static let preview = FriendsClient(
        friends: { Friend.previews },
        myShelf: { .preview },
        profile: { _ in .preview },
        libraryPage: { _, _, _, _ in (FriendProfile.preview.favorites + FriendProfile.preview.reading, false) },
        sagaPage: { _, _, _, _ in ([], false) },
        book: { _, _ in .preview },
        audio: { _, _ in .available },
        addBook: { _, _, _, _ in },
        offer: { _, _ in EditionOffer() },
        awaitEdition: { _, _, format in .pending(format: format, of: FriendBook.preview.book) },
        stopAwaiting: { _ in },
        invite: { .preview },
        accept: { _ in Friend.previews[1] },
        remove: { _ in }
    )
}
