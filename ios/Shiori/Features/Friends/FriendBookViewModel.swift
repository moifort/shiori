import Foundation

/// A friend's book: the book itself, whether Audible sells it, what may be
/// awaited of it in the app's language, and what the reader took of it.
@MainActor
@Observable
final class FriendBookViewModel {
    let friendId: String
    let bookId: String

    private(set) var entry: FriendBook?
    private(set) var isLoading = true
    private(set) var errorMessage: String?
    /// What the reader just did with it from the "+" in the corner.
    private(set) var added: CopiedStatus?
    /// Whether Audible sells the book, for a printed one: until it answers,
    /// and when it cannot, the reader may still take it heard.
    private(set) var audio: AudioAvailability?
    /// What the page offers to await in the app's language, and what the
    /// reader awaits already.
    private(set) var offer = EditionOffer()
    /// A write that failed, said in an alert.
    var addFailed: String?

    private let client: FriendsClient
    /// The awaits sent and not answered yet, by format: the page already shows
    /// them, so giving one up waits for the server's id.
    private var awaiting: [ReleaseFormat: Task<AwaitedEdition?, Never>] = [:]

    init(friendId: String, bookId: String, client: FriendsClient) {
        self.friendId = friendId
        self.bookId = bookId
        self.client = client
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            entry = try await client.book(friendId, bookId)
        } catch {
            errorMessage = reportError(error)
        }
        isLoading = false
    }

    func loadAudio() async {
        do {
            audio = try await client.audio(friendId, bookId)
        } catch {
            _ = reportError(error)
        }
    }

    func loadOffer() async {
        do {
            offer = try await client.offer(friendId, bookId) ?? EditionOffer()
        } catch {
            _ = reportError(error)
        }
    }

    /// Onto the reader's shelf, in the format they take it in. True once it is.
    func add(_ status: CopiedStatus, as format: BookFormat) async -> Bool {
        do {
            try await client.addBook(friendId, bookId, status, format)
            added = status
            return true
        } catch {
            addFailed = reportError(error)
            return false
        }
    }

    /// Awaits the book's edition in the app's language. The page shows it
    /// awaited at once, with no loader: the server looks it up on the web
    /// behind, and its answer replaces the line when it comes.
    func awaitEdition(_ format: ReleaseFormat) {
        guard let book = entry?.book else { return }
        let pending = AwaitedEdition.pending(format: format, of: book)
        offer.awaited.append(pending)
        let (client, friendId, bookId) = (client, friendId, bookId)
        awaiting[format] = Task {
            defer { awaiting[format] = nil }
            do {
                let edition = try await client.awaitEdition(friendId, bookId, format)
                // Unless the reader gave it up meanwhile.
                if let index = offer.awaited.firstIndex(where: { $0.id == pending.id }) {
                    offer.awaited[index] = edition
                }
                return edition
            } catch {
                offer.awaited.removeAll { $0.id == pending.id }
                addFailed = reportError(error)
                return nil
            }
        }
    }

    func stopAwaiting(_ edition: AwaitedEdition) async {
        var edition = edition
        // Given up before the server answered: stopped once it has.
        if let pending = awaiting[edition.format] {
            offer.awaited.removeAll { $0.id == edition.id }
            guard let answered = await pending.value else { return }
            edition = answered
        }
        do {
            try await client.stopAwaiting(edition.id)
            offer.awaited.removeAll { $0.id == edition.id }
        } catch {
            addFailed = reportError(error)
        }
    }
}
