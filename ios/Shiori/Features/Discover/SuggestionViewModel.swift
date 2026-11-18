import Foundation

/// A suggestion's page: its description, asked for when it opens, and what
/// the reader decides about it.
@MainActor
@Observable
final class SuggestionViewModel {
    init(suggestion: Suggestion, client: DiscoverClient) {
        self.suggestion = suggestion
        self.client = client
        let item = ReleaseItem.suggestion(id: suggestion.id, format: suggestion.format)
        describer = ReleaseDescriber(release: suggestion.release) { try await client.describe(item) }
    }

    let suggestion: Suggestion
    private let client: DiscoverClient
    private let describer: ReleaseDescriber

    /// The suggestion as its list drew it, then as the server described it.
    var shown: Book { describer.release.book(id: "suggestion-\(suggestion.id)") }
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
    /// The editions awaited here, which "Guetter" or its capsule pressed
    /// again stops.
    private var awaitedIds: [ReleaseFormat: String] = [:]
    /// Why a choice could not be made, said in an alert.
    var actionError: String?

    /// A choice from the page's "+" or eye, the page staying open on it. Says
    /// whether the server took it: the buttons stay as they were otherwise.
    func choose(_ suggestion: Suggestion, _ choice: DiscoveryChoice) async -> Bool {
        do {
            switch choice {
            case .add:
                bookAdded = try await client.addSuggestion(suggestion.shelfDraft(status: .toRead))
            case let .await(format):
                awaitedIds[format] = try await client.awaitEdition(suggestion.draft, format).id
            case .alreadyRead:
                bookRead = try await client.addSuggestion(suggestion.shelfDraft(status: .read))
            case .wish:
                wishId = try await client.wish(suggestion.shelfDraft(status: .toRead), .discovery, nil)
            case .unwish:
                if let wishId { try await client.removeWish(wishId) }
                wishId = nil
            case .undoAlreadyRead:
                if let bookRead { try await client.deleteBook(bookRead) }
                bookRead = nil
            case .undoAdd:
                if let bookAdded { try await client.deleteBook(bookAdded) }
                bookAdded = nil
            case let .unawait(format):
                // Awaited here, or already when the page opened.
                let id = awaitedIds[format] ?? (suggestion.format == format ? suggestion.awaitedEditionId : nil)
                if let id { try await client.stopAwaiting(id) }
                awaitedIds[format] = nil
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
