import Foundation

/// Owns one book's screen. Every mutation returns the whole record, so the
/// model replaces its book wholesale rather than patching the field it asked
/// about — rating a book also marks it read, and only the server's answer knows
/// the full consequence.
@MainActor
@Observable
final class BookViewModel {
    private(set) var book: Book?
    private(set) var isLoading = true
    private(set) var errorMessage: String?
    /// Set while a mutation is in flight, so the screen can disable its controls
    /// without blanking the content underneath.
    private(set) var isSaving = false

    private let bookId: String

    init(bookId: String) {
        self.bookId = bookId
    }

    /// The book alone: its saga's catalogue is the series screen's business,
    /// one tap away, and reading it here cost a catalogue call per opening.
    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            book = try await BookAPI.book(id: bookId)
        } catch {
            errorMessage = reportError(error)
        }
        isLoading = false
    }

    func setStatus(_ status: ReadingStatus) async {
        await mutate { try await BookAPI.setStatus(id: self.bookId, status: status) }
    }

    func rate(_ stars: Int) async {
        await mutate { try await BookAPI.rate(id: self.bookId, stars: stars) }
    }

    /// Saves the edit form: the corrected facts first, then the rating when it
    /// moved. Two calls, because rating is its own mutation with its own rule —
    /// it marks the book read — and the record the second one returns carries
    /// both changes. Returns false when a call failed, so the form stays open.
    func save(_ correction: BookCorrection, rating: Int?) async -> Bool {
        guard let book else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            // One request for the whole sheet: the stars ride the correction,
            // and only when they changed.
            let saved = try await BookAPI.save(
                id: bookId,
                correction: correction,
                rating: rating != book.rating ? .some(rating) : .none
            )
            if let saved { self.book = saved }
            return true
        } catch {
            errorMessage = reportError(error)
            return false
        }
    }

    func setFavorite(_ favorite: Bool) async {
        await mutate { try await BookAPI.setFavorite(id: self.bookId, favorite: favorite) }
    }

    func setHidden(_ hidden: Bool) async {
        await mutate { try await BookAPI.setHidden(id: self.bookId, hidden: hidden) }
    }

    func delete() async -> Bool {
        isSaving = true
        defer { isSaving = false }
        do {
            try await BookAPI.delete(id: bookId)
            return true
        } catch {
            errorMessage = reportError(error)
            return false
        }
    }

    private func mutate(_ operation: @escaping () async throws -> Book) async {
        isSaving = true
        defer { isSaving = false }
        do {
            book = try await operation()
        } catch {
            errorMessage = reportError(error)
        }
    }

    func dismissError() {
        errorMessage = nil
    }
}
