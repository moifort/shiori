import SwiftUI

/// An awaited edition's page: its description, asked for when it opens, and
/// the saga of the reader's copy it is awaited of.
@MainActor
@Observable
final class AwaitedEditionViewModel {
    init(edition: AwaitedEdition, client: DiscoverClient) {
        self.edition = edition
        self.client = client
        describer = ReleaseDescriber(describe: client.describe)
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

    /// The edition once described, as a book's page draws it.
    var shown: Book {
        var book = edition.cover.described(by: describer.description)
        if book.series == nil { book.series = series }
        return book
    }
    var isDescribing: Bool { describer.isDescribing }

    private(set) var added = false
    /// Why the addition failed, for the alert; nil once read.
    var addFailed: String?

    func describe() async { await describer.describe(edition.seed) }

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
            sagaVolumes = volumes
        }
    }

    /// Onto the pile, as the page shows it, filed in the saga of the reader's
    /// copy. Once held, the edition is no longer awaited: the server lets the
    /// wait go on the next reading of the list.
    func add() async {
        do {
            try await client.addBook(edition.draft(from: shown))
            added = true
        } catch {
            addFailed = reportError(error)
        }
    }
}
