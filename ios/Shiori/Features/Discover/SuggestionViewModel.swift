import Foundation

/// A suggestion's page: its description, asked for when it opens, and what
/// the reader decides about it.
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

    /// The book said read here, which the check pressed again takes off the
    /// shelf.
    private var bookRead: String?
    /// Why a choice could not be made, said in an alert.
    var actionError: String?

    /// A choice from the page's "+" or eye, the page staying open on it. Says
    /// whether the server took it: the buttons stay as they were otherwise.
    func choose(_ suggestion: Suggestion, _ choice: DiscoveryChoice) async -> Bool {
        do {
            switch choice {
            case .add:
                _ = try await client.addSuggestion(suggestion.shelfDraft(status: .toRead))
            case let .await(format):
                _ = try await client.awaitEdition(suggestion.draft, format)
            case .alreadyRead:
                bookRead = try await client.addSuggestion(suggestion.shelfDraft(status: .read))
            case .wish:
                try await client.wish(suggestion.shelfDraft(status: .toRead), .discovery, nil)
            case .undoAlreadyRead:
                if let bookRead { try await client.deleteBook(bookRead) }
                bookRead = nil
            case .notInterested:
                try await client.dismissSuggestion(suggestion.id, .notInterested)
            case .reconsider:
                try await client.reconsiderSuggestion(suggestion.id)
            }
            return true
        } catch {
            actionError = reportError(error)
            return false
        }
    }

    /// The book as it goes onto the shelf.
    func draft(status: ReadingStatus) -> BookDraft { suggestion.shelfDraft(status: status) }
}

extension Suggestion {
    /// The book as it goes onto the shelf.
    func shelfDraft(status: ReadingStatus) -> BookDraft {
        var draft = self.draft
        draft.title = title
        draft.language = nil
        draft.coverURL = coverURL
        draft.format = format == .audiobook ? .audiobook : .book
        if draft.format == .audiobook { draft.media = [] }
        draft.status = status
        return draft
    }
}
