import Foundation

/// A suggestion's page: its description, asked for when it opens, and what
/// takes it off the line — an addition or a wait.
@MainActor
@Observable
final class SuggestionViewModel {
    init(suggestion: Suggestion, client: DiscoverClient) {
        self.suggestion = suggestion
        self.client = client
        describer = ReleaseDescriber(describe: client.describe)
    }

    let suggestion: Suggestion
    private let client: DiscoverClient
    private let describer: ReleaseDescriber

    /// The suggestion once described, as a book's page draws it.
    var shown: Book { suggestion.cover.described(by: describer.description) }
    var isDescribing: Bool { describer.isDescribing }

    func describe() async { await describer.describe(suggestion.seed) }

    /// Puts it on the shelf — on the pile, or read already — in the format the
    /// line is drawn in, under its title in the app's language. The page is
    /// closed by then, so a failure is reported rather than shown.
    func add(status: ReadingStatus) async {
        do {
            try await client.addBook(draft(status: status))
        } catch {
            _ = reportError(error)
        }
    }

    /// Awaits its edition in the app's language, in this format.
    func awaitEdition(_ format: ReleaseFormat) async {
        do {
            _ = try await client.awaitEdition(suggestion.draft, format)
        } catch {
            _ = reportError(error)
        }
    }

    /// The book as it goes onto the shelf.
    func draft(status: ReadingStatus) -> BookDraft {
        var draft = suggestion.draft
        draft.title = suggestion.title
        draft.language = nil
        draft.coverURL = suggestion.coverURL
        draft.format = suggestion.format == .audiobook ? .audiobook : .book
        if draft.format == .audiobook { draft.media = [] }
        draft.status = status
        return draft
    }
}
