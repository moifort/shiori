import Foundation
import SwiftUI

/// Owns the wishlist: the books wished for and the editions awaited, loaded
/// at once — a few dozen — and cut into sections by the model.
@MainActor
@Observable
final class WishlistViewModel {
    init(client: WishlistClient, caching: Bool = true) {
        self.client = client
        cache = caching ? SnapshotCache("wishlist", version: 1) : nil
        wishlist = cache?.read() ?? Wishlist()
    }

    private let client: WishlistClient
    private let cache: SnapshotCache<Wishlist>?

    private(set) var wishlist: Wishlist
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    /// Why a wish could not be acted on, said in an alert.
    var actionError: String?
    var format: BookFormat?

    private var loaded = false

    /// The formats the pills offer: the ones the list holds.
    var formats: [BookFormat] {
        let held = Set(wishlist.wishes.map(\.format) + wishlist.awaited.map(\.cover.format))
        return BookFormat.allCases.filter(held.contains)
    }

    /// The list narrowed to the format picked.
    var shown: Wishlist {
        guard let format else { return wishlist }
        return Wishlist(
            wishes: wishlist.wishes.filter { $0.format == format },
            awaited: wishlist.awaited.filter { $0.cover.format == format }
        )
    }

    func loadOnAppear() async {
        guard !loaded, !isLoading else { return }
        await load()
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await client.wishlist()
            withAnimation(wishlist.isEmpty ? nil : .smooth) { wishlist = fetched }
            loaded = true
            if let format, !formats.contains(format) { self.format = nil }
            if let cache { Task.detached { cache.write(fetched) } }
        } catch {
            guard !isCancellation(error) else {
                isLoading = false
                return
            }
            errorMessage = reportError(error)
        }
        isLoading = false
    }

    /// Onto the shelf, on the pile or among the books read: the wish leaves
    /// the list, which the server confirms on the next load.
    func add(_ wish: Wish, status: ReadingStatus) async {
        await act(dropping: wish) { try await self.client.addBook(wish.draft(status: status)) }
    }

    func remove(_ wish: Wish) async {
        await act(dropping: wish) { try await self.client.remove(wish.id) }
    }

    private func act(dropping wish: Wish, _ work: @escaping () async throws -> Void) async {
        do {
            try await work()
            withAnimation(.smooth) { wishlist.wishes.removeAll { $0.id == wish.id } }
        } catch {
            guard !isCancellation(error) else { return }
            actionError = reportError(error)
        }
    }
}
