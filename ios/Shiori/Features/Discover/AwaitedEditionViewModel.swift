import SwiftUI

/// An awaited edition's page: its description, asked for when it opens, and
/// the saga of the reader's copy it is awaited of.
@MainActor
@Observable
final class AwaitedEditionViewModel {
    init(edition: AwaitedEdition, client: DiscoverClient) {
        self.edition = edition
        self.client = client
        let item = ReleaseItem.awaitedEdition(id: edition.id)
        describer = ReleaseDescriber(release: edition.release) { try await client.describe(item) }
    }

    let edition: AwaitedEdition
    private let client: DiscoverClient
    private let describer: ReleaseDescriber

    /// The saga of the reader's copy, and its volumes held or lacking, its
    /// copy among them. Empty for a book on its own.
    private(set) var sagaVolumes: [SeriesStripItem] = []
    /// The saga and the place in it of the reader's copy: the edition's own,
    /// over its title.
    private(set) var series: SeriesMembership?
    var sagaName: String? { series?.name }
    /// The reader's copy, read for its saga's row.
    private var copy: Book?

    /// The saga of the reader's copy, as the page of a volume of it they lack
    /// reads it.
    var lackingSaga: SagaDiscovery? {
        guard let copy, let series else { return nil }
        let owned = sagaVolumes.count { if case .owned = $0 { true } else { false } }
        return SagaDiscovery(holding: copy, in: series, ownedCount: owned)
    }

    /// The edition as its list drew it, then as the server described it, in
    /// the saga of the reader's copy.
    var shown: Book {
        var book = describer.release.book(id: "awaited-\(edition.id)")
        if book.series == nil { book.series = series }
        return book
    }
    var isDescribing: Bool { describer.isDescribing }
    /// The release the page shows: its cover is picked for every reader.
    var releaseKey: String { describer.release.key }

    /// The cover picked for it, drawn at once.
    func drawCover(_ url: URL) { describer.drawCover(url) }

    private(set) var added = false
    /// What the "+" made of the edition, said in its capsule.
    private(set) var taken: TakenState?
    /// On the wishlist, from "Envies".
    private(set) var isWished = false
    /// Bumped on each refusal: the hero's buttons shake.
    private(set) var refusals = 0
    /// The book put on the shelf and the wish made here, which a second tap
    /// takes back.
    private var bookAdded: String?
    private var wishId: String?
    /// Why adding it or giving it up failed, for the alert; nil once read.
    var actionError: String?

    func describe() async { await describer.describe() }

    /// The reader's copy, then its saga's row off the catalogue already
    /// built. Nothing when either fails, the page whole without it.
    func loadSaga() async {
        guard let bookId = edition.bookId,
              let book = try? await client.book(bookId),
              let series = book.series,
              let volumes = try? await client.sagaVolumes(series.id, book.language)
        else { return }
        withAnimation(.snappy) {
            self.series = series
            copy = book
            sagaVolumes = volumes
        }
    }

    /// Onto the pile, as the page shows it, filed in the saga of the reader's
    /// copy. Once held, the edition is no longer awaited: the server lets the
    /// wait go on the next reading of the list.
    /// No longer awaited, given up from the page itself. Says whether it went;
    /// a failure is said in the alert.
    func stopAwaiting() async -> Bool {
        do {
            try await client.stopAwaiting(edition.id)
            return true
        } catch {
            guard !isCancellation(error) else { return false }
            actionError = reportError(error)
            return false
        }
    }

    /// Onto the pile as shown, or read already.
    func add(_ addition: UnownedBookAddition = .pile) async {
        if addition == .wishlist {
            await toggleWish()
            return
        }
        do {
            var draft = edition.draft(from: shown)
            if addition == .read { draft.status = .read }
            bookAdded = try await client.addSuggestion(draft)
            let isAudio = edition.format == .audiobook
            taken = addition == .read ? .read(isAudio: isAudio) : .toRead(isAudio: isAudio)
            added = true
        } catch {
            refusals += 1
            actionError = reportError(error)
        }
    }

    /// The capsule pressed again: the edition leaves the shelf.
    func undoAdd() async {
        do {
            if let bookAdded { try await client.deleteBook(bookAdded) }
            bookAdded = nil
            taken = nil
            added = false
        } catch {
            refusals += 1
            actionError = reportError(error)
        }
    }

    /// "Envies": onto the wishlist, or off it again.
    func toggleWish() async {
        do {
            if let wishId {
                try await client.removeWish(wishId)
                self.wishId = nil
                isWished = false
            } else {
                wishId = try await client.wish(edition.draft(from: shown), .discovery, nil)
                isWished = true
            }
        } catch {
            refusals += 1
            actionError = reportError(error)
        }
    }
}
