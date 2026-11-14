import SwiftUI

/// A book wished for, on its own page: its description, asked for when it
/// opens, and what the reader makes of it — on the pile, read already, or
/// off the list.
@MainActor
@Observable
final class WishViewModel {
    init(wish: Wish, client: WishlistClient, discover: DiscoverClient) {
        self.wish = wish
        self.client = client
        let item = ReleaseItem.wish(id: wish.id)
        describer = ReleaseDescriber(release: wish.release) { try await discover.describe(item) }
    }

    let wish: Wish
    private let client: WishlistClient
    private let describer: ReleaseDescriber

    /// The wish as the list drew it, then as the server described it.
    var shown: Book { describer.release.book(id: "wish-\(wish.id)") }
    var storeURL: URL? { describer.release.storeURL }
    var isDescribing: Bool { describer.isDescribing }

    /// Why an action failed, for the alert; nil once read.
    var actionError: String?

    func describe() async { await describer.describe() }

    /// Onto the shelf: the wish then goes on its own. Says whether it went.
    func add(status: ReadingStatus) async -> Bool {
        await act { try await self.client.addBook(self.wish.draft(status: status)) }
    }

    /// Off the list. Says whether it went.
    func remove() async -> Bool {
        await act { try await self.client.remove(self.wish.id) }
    }

    private func act(_ work: @escaping () async throws -> Void) async -> Bool {
        do {
            // The pile and the list read it again on the notice the call posts.
            try await work()
            return true
        } catch {
            guard !isCancellation(error) else { return false }
            actionError = reportError(error)
            return false
        }
    }
}

extension Wish {
    /// The release its page starts from: what the list knew of it, out, to
    /// be described.
    var release: Release {
        Release(
            key: "wish-\(id)",
            title: title,
            authors: authors,
            releaseFormat: format == .audiobook ? .audiobook : .book,
            format: format,
            language: language,
            state: .available,
            watched: false,
            isbn13: isbn13,
            coverURL: coverURL
        )
    }

    /// Where it came from, under its author: the friend who recommended it,
    /// else the origin its cover is labelled with.
    var originLine: String {
        if origin == .friend, let originLabel {
            return String(localized: "Liste d'envies · conseillé par \(originLabel)")
        }
        return String(localized: "Liste d'envies · \(originCaption)")
    }
}
