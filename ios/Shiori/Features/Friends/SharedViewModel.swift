import Foundation
import SwiftUI

/// Owns the Partagé tab: the reader's own shelf as their friends see it, the
/// friends, and the one in-flight load. The tab opens on what it last showed:
/// a `SnapshotCache` hands it back from disk before a byte is asked of the
/// network, and the fetch brings it up to date silently underneath.
@MainActor
@Observable
final class SharedViewModel {
    init() {
        if let snapshot = cache.read() {
            friends = snapshot.friends
            myShelf = snapshot.myShelf
        }
    }

    private(set) var friends: [Friend] = []
    private(set) var myShelf: FriendProfile?
    private(set) var isLoading = false
    /// The friends list could not be read. Only drawn when there is nothing
    /// else on screen.
    private(set) var loadFailed: String?

    /// Bringing last session's rows up to date failed: they are the ones from
    /// last time, and the leading row offers to try again.
    private(set) var refreshFailed = false
    /// The server has answered at least once, so the rows are no longer the
    /// snapshot.
    private(set) var loaded = false

    /// What the tab opens on.
    private struct Snapshot: Codable {
        let friends: [Friend]
        let myShelf: FriendProfile?
    }

    /// The last rows on disk. Bump the version whenever `Friend` or
    /// `FriendProfile` changes shape.
    private let cache = SnapshotCache<Snapshot>("shared", version: 1)

    var isEmpty: Bool { friends.isEmpty && myShelf == nil }

    /// Says whether it failed. One skipped because another was already on its
    /// way, or one called off, did not: the rows are whatever that other one
    /// brings.
    @discardableResult
    func load() async -> Bool {
        guard !isLoading else { return false }
        isLoading = true
        defer { isLoading = false }
        // The two reads are independent: the preview still opens when the
        // friends list fails, and the other way round.
        async let shelf = FriendsAPI.myShelf()
        var fetchedFriends: [Friend]?
        var fetchedShelf: FriendProfile?
        var failed = false
        do {
            fetchedFriends = try await FriendsAPI.friends()
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
        if !failed {
            // Fresh rows: whatever an earlier refresh said is no longer true.
            refreshFailed = false
            write()
        }
        return failed
    }

    /// The tab appeared: rows still showing last session's snapshot refresh,
    /// a tab never loaded loads. One the server already answered asks nothing:
    /// every write posts the change notice this tab listens to.
    func loadOnAppear() async {
        guard !loaded, !isLoading else { return }
        if !isEmpty {
            await refresh()
        } else {
            await load()
        }
    }

    /// Bring the rows on screen up to date without taking them away — and the
    /// retry when that failed.
    func refresh() async {
        refreshFailed = false
        refreshFailed = await load()
    }

    /// A friend the reader just accepted: filed where the server files it, by
    /// first name, rather than read back with the whole list.
    func add(_ friend: Friend) {
        withAnimation(.smooth) {
            friends = (friends.filter { $0.userId != friend.userId } + [friend])
                .sorted { ($0.firstName ?? "").localizedCompare($1.firstName ?? "") == .orderedAscending }
        }
        write()
    }

    /// A friend the reader stopped sharing with.
    func remove(_ friend: Friend) {
        withAnimation(.smooth) { friends.removeAll { $0.userId == friend.userId } }
        write()
    }

    private func write() {
        let cache = cache
        let snapshot = Snapshot(friends: friends, myShelf: myShelf)
        Task.detached { cache.write(snapshot) }
    }
}
