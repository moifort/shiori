import Foundation

/// An award winner's page: its description, asked for when it opens, and what
/// the reader decides about it.
@MainActor
@Observable
final class AwardWinnerViewModel {
    init(winner: AwardWinner, client: DiscoverClient) {
        self.winner = winner
        self.client = client
        // A winner read back from a snapshot saved before its key was sent is
        // not described: its page stays the one its list drew.
        let item = winner.key.map { ReleaseItem.awardWinner(key: $0, format: winner.format) }
        var release = winner.release
        if item == nil { release.described = true }
        describer = ReleaseDescriber(release: release) {
            guard let item else { throw CancellationError() }
            return try await client.describe(item)
        }
    }

    let winner: AwardWinner
    private let client: DiscoverClient
    private let describer: ReleaseDescriber

    /// The winner as its list drew it, then as the server described it.
    var shown: Book { describer.release.book(id: "award-\(winner.id)") }
    var isDescribing: Bool { describer.isDescribing }
    /// The release the page shows: its cover is picked for every reader.
    var releaseKey: String { describer.release.key }

    /// The cover picked for it, drawn at once.
    func drawCover(_ url: URL) { describer.drawCover(url) }

    func describe() async { await describer.describe() }

    /// The book said read here, which the check pressed again takes off the
    /// shelf.
    private var bookRead: String?
    /// The wish made here, which "Envies" tapped again takes back.
    private var wishId: String?
    /// The book put on the pile here, which its capsule pressed again takes
    /// off the shelf.
    private var bookAdded: String?
    /// The edition awaited here, which its capsule pressed again stops.
    private var awaitedId: String?
    /// Why a choice could not be made, said in an alert.
    var actionError: String?

    /// A choice from the page's "+" or eye, the page staying open on it. Says
    /// whether the server took it: the buttons stay as they were otherwise.
    func choose(_ winner: AwardWinner, _ choice: DiscoveryChoice) async -> Bool {
        do {
            switch choice {
            case .add:
                bookAdded = try await client.addSuggestion(winner.pileDraft)
            case let .await(format):
                awaitedId = try await client.awaitEdition(winner.draft, format).id
            case .alreadyRead:
                var draft = winner.pileDraft
                draft.status = .read
                bookRead = try await client.addSuggestion(draft)
            case .wish:
                wishId = try await client.wish(winner.pileDraft, .award, winner.mentions.first?.award.name)
            case .unwish:
                if let wishId { try await client.removeWish(wishId) }
                wishId = nil
            case .undoAlreadyRead:
                if let bookRead { try await client.deleteBook(bookRead) }
                bookRead = nil
            case .undoAdd:
                if let bookAdded { try await client.deleteBook(bookAdded) }
                bookAdded = nil
            case .unawait:
                if let awaitedId { try await client.stopAwaiting(awaitedId) }
                awaitedId = nil
            case .notInterested:
                if let key = winner.key { try await client.dismissWinner(key) }
            case .reconsider:
                if let key = winner.key { try await client.reconsiderWinner(key) }
            }
            return true
        } catch {
            actionError = reportError(error)
            return false
        }
    }
}
