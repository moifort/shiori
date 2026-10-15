import Foundation

/// An awaited edition's page: its description, asked for when it opens.
@MainActor
@Observable
final class AwaitedEditionViewModel {
    init(edition: AwaitedEdition, client: DiscoverClient) {
        self.edition = edition
        describer = ReleaseDescriber(describe: client.describe)
    }

    let edition: AwaitedEdition
    private let describer: ReleaseDescriber

    /// The edition once described, as a book's page draws it.
    var shown: Book { edition.cover.described(by: describer.description) }
    var isDescribing: Bool { describer.isDescribing }

    func describe() async { await describer.describe(edition.seed) }
}
