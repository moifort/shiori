import SwiftUI

/// One friend's shelf, summed up — or the reader's own, previewed from the
/// shelf already in hand. The page opens on the shelf it showed last time,
/// kept on disk per friend, and the server's answer slides into place.
@MainActor
@Observable
final class FriendProfileViewModel {
    let friend: Friend
    /// The reader's own page as their friends see it: nothing is asked of the
    /// server, every book is the reader's already.
    let isPreview: Bool

    private(set) var profile: FriendProfile?
    private(set) var isLoading: Bool
    /// Only drawn when there is no shelf on screen.
    private(set) var errorMessage: String?

    private let client: FriendsClient
    /// Nil on the preview, which draws the shelf already in hand.
    private let cache: SnapshotCache<FriendProfile>?

    init(friend: Friend, client: FriendsClient) {
        self.friend = friend
        self.client = client
        isPreview = false
        // Bump the version whenever `FriendProfile` changes shape.
        let cache = SnapshotCache<FriendProfile>("friend-\(friend.userId)", version: 1)
        self.cache = cache
        profile = cache.read()
        isLoading = true
    }

    init(preview shelf: FriendProfile) {
        friend = Friend(seenByFriends: shelf)
        client = .preview
        isPreview = true
        cache = nil
        profile = shelf
        isLoading = false
    }

    /// The shelf last shown stays while the server is asked again. A refresh
    /// that fails over a shelf already on screen says nothing — a pull tries
    /// again — and only an empty page shows the failure.
    func load() async {
        guard !isPreview else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await client.profile(friend.userId)
            withAnimation(profile == nil ? nil : .smooth) { profile = fetched }
            errorMessage = nil
            write()
        } catch {
            guard !isCancellation(error) else { return }
            let message = reportError(error)
            if profile == nil { errorMessage = message }
        }
    }

    /// The book is the reader's now: every shelf of the page says so, without
    /// asking the server for the whole profile again.
    func markOwned(_ bookId: String) {
        guard var profile else { return }
        profile.markOwned(bookId)
        self.profile = profile
        write()
    }

    private func write() {
        guard let cache, let profile else { return }
        Task.detached { cache.write(profile) }
    }
}

extension FriendProfile {
    /// Says on every shelf of the profile that the reader now holds the book.
    mutating func markOwned(_ bookId: String) {
        for index in reading.indices where reading[index].id == bookId {
            reading[index].inLibrary = true
        }
        for index in pile.indices where pile[index].id == bookId {
            pile[index].inLibrary = true
        }
        for index in favorites.indices where favorites[index].id == bookId {
            favorites[index].inLibrary = true
        }
        if lastFinished?.id == bookId { lastFinished?.inLibrary = true }
        if lastDropped?.id == bookId { lastDropped?.inLibrary = true }
        if lastAdded?.id == bookId { lastAdded?.inLibrary = true }
    }
}
