import Foundation
import SwiftUI

/// Owns the Amis tab: the friends, the ones the reader picked, and the rails
/// drawn from their shelves. Picking nobody shows every friend; each friend
/// tapped narrows the page to the friends picked, and tapping them again
/// widens it back.
///
/// The tab opens on what it last showed for the same pick: one snapshot per
/// pick, read before a byte is asked of the network, brought up to date
/// silently underneath.
@MainActor
@Observable
final class FriendsViewModel {
    /// - Parameter caching: off in tests, which must neither read nor leave
    ///   a snapshot on disk.
    init(client: FriendsClient, caching: Bool = true) {
        self.client = client
        self.caching = caching
        friendsCache = caching ? SnapshotCache<[Friend]>("friends-tab-friends", version: 1) : nil
        friends = friendsCache?.read() ?? []
        if let shelf = shelfCache(for: [])?.read() { self.shelf = shelf }
    }

    private let client: FriendsClient
    private let caching: Bool
    private let friendsCache: SnapshotCache<[Friend]>?

    private(set) var friends: [Friend] = []
    /// The friends picked, in the order tapped. Empty means every friend.
    private(set) var selected: [String] = []
    private(set) var shelf = FriendsShelf()
    /// The reader's own shelf, for the page without a friend: what their
    /// friends will see of them.
    private(set) var myShelf: FriendProfile?
    private(set) var isLoading = false
    /// The server has answered at least once, so the page is no longer the
    /// snapshot.
    private(set) var loaded = false
    /// Nothing could be read. Only drawn when there is nothing else on screen.
    private(set) var loadFailed: String?

    /// The invitation just created, shown as a sheet the moment it comes back.
    var invitation: FriendInvitation?
    private(set) var isInviting = false
    var errorMessage: String?

    /// A reload in flight for an older pick is dropped when it lands.
    private var generation = 0

    var hasNoFriend: Bool { loaded && friends.isEmpty }
    var isEmpty: Bool { friends.isEmpty && shelf.isEmpty }

    /// The one friend picked, whose library and series the rows open.
    var soleFriend: Friend? {
        guard selected.count == 1 else { return nil }
        return friends.first { $0.userId == selected[0] }
    }

    func loadOnAppear() async {
        guard !loaded, !isLoading else { return }
        await load()
    }

    /// The friends and the rails for the current pick. A refresh that fails
    /// over a page already on screen says nothing.
    func load() async {
        isLoading = true
        defer { isLoading = false }
        generation += 1
        let current = generation
        let pick = selected
        do {
            async let fetchedFriends = client.friends()
            async let fetchedShelf = client.friendsShelf(pick)
            let (newFriends, newShelf) = try await (fetchedFriends, fetchedShelf)
            guard current == generation else { return }
            withAnimation(isEmpty ? nil : .smooth) {
                friends = newFriends
                // A friend gone since drops out of the pick.
                selected = selected.filter { id in newFriends.contains { $0.userId == id } }
                shelf = newShelf
            }
            loaded = true
            loadFailed = nil
            write(friends: newFriends, shelf: newShelf, for: pick)
            if newFriends.isEmpty { await loadMyShelf() }
        } catch {
            guard !isCancellation(error) else { return }
            let message = reportError(error)
            if isEmpty { loadFailed = message }
        }
    }

    /// A friend's avatar tapped: picked, or let go when already picked. The
    /// page shows that pick's last rails at once, then asks for them.
    func toggle(_ friendId: String) async {
        if selected.contains(friendId) {
            selected.removeAll { $0 == friendId }
        } else {
            selected.append(friendId)
        }
        if let cached = shelfCache(for: selected)?.read() {
            withAnimation(.smooth) { shelf = cached }
        }
        await load()
    }

    /// One friend alone, asked for from another tab: the pick is that
    /// friend, whatever was picked before.
    func show(only friendId: String) async {
        guard selected != [friendId] else { return }
        selected = [friendId]
        if let cached = shelfCache(for: selected)?.read() {
            withAnimation(.smooth) { shelf = cached }
        }
        await load()
    }

    func invite() async {
        isInviting = true
        defer { isInviting = false }
        do {
            invitation = try await client.invite()
        } catch {
            errorMessage = reportError(error)
        }
    }

    private func loadMyShelf() async {
        do {
            myShelf = try await client.myShelf()
        } catch {
            if !isCancellation(error) { _ = reportError(error) }
        }
    }

    /// One file per pick, the friends sorted so the same pick finds its file
    /// whatever order they were tapped in.
    private func shelfCache(for pick: [String]) -> SnapshotCache<FriendsShelf>? {
        guard caching else { return nil }
        let key = pick.isEmpty ? "all" : pick.sorted().joined(separator: "-")
        return SnapshotCache<FriendsShelf>("friends-tab-shelf-\(key)", version: 1)
    }

    private func write(friends: [Friend], shelf: FriendsShelf, for pick: [String]) {
        let friendsCache = friendsCache
        let shelfCache = shelfCache(for: pick)
        Task.detached {
            friendsCache?.write(friends)
            shelfCache?.write(shelf)
        }
    }
}
