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

    func describe() async { await describer.describe() }

    /// The book said read here, which the check pressed again takes off the
    /// shelf.
    private var bookRead: String?
    /// Why a choice could not be made, said in an alert.
    var actionError: String?

    /// A choice from the page's "+" or eye, the page staying open on it. Says
    /// whether the server took it: the buttons stay as they were otherwise.
    func choose(_ winner: AwardWinner, _ choice: DiscoveryChoice) async -> Bool {
        do {
            switch choice {
            case .add:
                try await client.addBook(winner.pileDraft)
            case let .await(format):
                _ = try await client.awaitEdition(winner.draft, format)
            case .alreadyRead:
                var draft = winner.pileDraft
                draft.status = .read
                bookRead = try await client.addSuggestion(draft)
            case .wish:
                try await client.wish(winner.pileDraft, .award, winner.mentions.first?.award.name)
            case .undoAlreadyRead:
                if let bookRead { try await client.deleteBook(bookRead) }
                bookRead = nil
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
