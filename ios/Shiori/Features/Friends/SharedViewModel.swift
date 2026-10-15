import Foundation
import SwiftUI

/// Owns the Partagé tab: the reader's own shelf as their friends see it, the
/// friends, and the one in-flight load. The tab opens on what it last showed:
/// a `SnapshotCache` hands it back from disk before a byte is asked of the
/// network, and the fetch brings it up to date silently underneath.
@MainActor
@Observable
final class SharedViewModel {
    init(client: FriendsClient) {
        self.client = client
        if let snapshot = cache.read() {
            friends = snapshot.friends
            myShelf = snapshot.myShelf
        }
    }

    private let client: FriendsClient

    private(set) var friends: [Friend] = []
    private(set) var myShelf: FriendProfile?
    private(set) var isLoading = false
    /// The friends list could not be read. Only drawn when there is nothing
    /// else on screen.
    private(set) var loadFailed: String?

    /// The server has answered at least once, so the rows are no longer the
    /// snapshot.
    private(set) var loaded = false

    /// The invitation just created, ready to send; the screen shows it as a
    /// sheet the moment it comes back.
    var invitation: FriendInvitation?
    private(set) var isInviting = false
    /// The first name of the friend an invitation just joined.
    var accepted: String?
    /// A write that failed, said in an alert.
    var errorMessage: String?

    /// What the tab opens on.
    private struct Snapshot: Codable {
        let friends: [Friend]
        let myShelf: FriendProfile?
    }

    /// The last rows on disk. Bump the version whenever `Friend` or
    /// `FriendProfile` changes shape.
    private let cache = SnapshotCache<Snapshot>("shared", version: 5)

    var isEmpty: Bool { friends.isEmpty && myShelf == nil }

    /// A refresh that fails over rows already on screen says nothing: they
    /// stay as they were, and a pull brings them up to date.
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        // The two reads are independent: the preview still opens when the
        // friends list fails, and the other way round.
        async let shelf = client.myShelf()
        var fetchedFriends: [Friend]?
        var fetchedShelf: FriendProfile?
        var failed = false
        do {
            fetchedFriends = try await client.friends()
            loadFailed = nil
        } catch {
            if !isCancellation(error) {
                loadFailed = reportError(error)
                failed = true
            }
        }
        do {
            fetchedShelf = try await shelf
        } catch {
            if !isCancellation(error) {
                _ = reportError(error)
                failed = true
            }
        }
        // Over rows already on screen, the new ones slide into place and push
        // the others aside rather than the whole list redrawing at once: a
        // friend's counts move, a new friend takes their place in the list.
        withAnimation(isEmpty ? nil : .smooth) {
            if let fetchedFriends { friends = fetchedFriends }
            if let fetchedShelf { myShelf = fetchedShelf }
        }
        if fetchedFriends != nil || fetchedShelf != nil { loaded = true }
        if !failed { write() }
    }

    /// The tab appeared: rows still showing last session's snapshot refresh,
    /// a tab never loaded loads. One the server already answered asks nothing:
    /// every write posts the change notice this tab listens to.
    func loadOnAppear() async {
        guard !loaded, !isLoading else { return }
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

    /// Takes an invitation up from the code or the link the reader pasted.
    func accept(code: String) async {
        let code = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }
        do {
            let friend = try await client.accept(code)
            accepted = friend.displayName
            // The answer is the new row, rather than read back with the whole list.
            add(friend)
        } catch {
            errorMessage = reportError(error)
        }
    }

    /// Stops sharing with a friend, both ways.
    func remove(_ friend: Friend) async {
        do {
            try await client.remove(friend.userId)
            withAnimation(.smooth) { friends.removeAll { $0.userId == friend.userId } }
            write()
        } catch {
            errorMessage = reportError(error)
        }
    }

    /// A friend the reader just accepted: filed where the server files it, by
    /// first name, rather than read back with the whole list.
    private func add(_ friend: Friend) {
        withAnimation(.smooth) {
            friends = (friends.filter { $0.userId != friend.userId } + [friend])
                .sorted { ($0.firstName ?? "").localizedCompare($1.firstName ?? "") == .orderedAscending }
        }
        write()
    }

    private func write() {
        let cache = cache
        let snapshot = Snapshot(friends: friends, myShelf: myShelf)
        Task.detached { cache.write(snapshot) }
    }
}
