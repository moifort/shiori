import Foundation

struct WishlistClient: Sendable {
    var wishlist: @Sendable () async throws -> Wishlist
    var remove: @Sendable (_ wishId: String) async throws -> Void
    /// Onto the shelf, on the pile or among the books read: the wish then
    /// goes on its own.
    var addBook: @Sendable (BookDraft) async throws -> Void
    var stopAwaiting: @Sendable (_ editionId: String) async throws -> Void
}

extension WishlistClient {
    static let live = WishlistClient(
        wishlist: { try await WishlistAPI.wishlist() },
        remove: { try await WishlistAPI.remove(id: $0) },
        addBook: { _ = try await BookAddition.add($0, source: .manual) },
        stopAwaiting: { try await AwaitedAPI.stop(id: $0) }
    )

    static let preview = WishlistClient(
        wishlist: { .preview },
        remove: { _ in },
        addBook: { _ in },
        stopAwaiting: { _ in }
    )
}
