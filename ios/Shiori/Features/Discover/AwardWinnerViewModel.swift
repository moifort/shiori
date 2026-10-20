import Foundation

/// An award winner's page: its description, asked for when it opens, and
/// what the "+" sends. The page is closed by the time the server answers, so
/// a failure is reported rather than shown.
@MainActor
@Observable
final class AwardWinnerViewModel {
    init(winner: AwardWinner, client: DiscoverClient) {
        self.winner = winner
        self.client = client
        describer = ReleaseDescriber(describe: client.describe)
    }

    let winner: AwardWinner
    private let client: DiscoverClient
    private let describer: ReleaseDescriber

    /// The winner once described, as a book's page draws it.
    var shown: Book { winner.cover.described(by: describer.description) }
    var isDescribing: Bool { describer.isDescribing }

    func describe() async { await describer.describe(winner.seed) }

    /// Puts it on the pile.
    func add() async {
        do {
            try await client.addBook(winner.pileDraft)
        } catch {
            _ = reportError(error)
        }
    }

    /// Awaits its edition in the app's language, in this format.
    func awaitEdition(_ format: ReleaseFormat) async {
        do {
            _ = try await client.awaitEdition(winner.draft, format)
        } catch {
            _ = reportError(error)
        }
    }
}
