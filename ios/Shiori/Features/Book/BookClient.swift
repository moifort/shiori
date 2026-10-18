import Foundation

/// Everything a book's screens ask of the server, as closures: `.live` goes
/// through `BookAPI` and `AwaitedAPI`, `.preview` answers from `Book.preview`,
/// and a test builds the one it needs inline.
struct BookClient: Sendable {
    var book: @Sendable (_ id: String) async throws -> Book?
    var add: @Sendable (BookDraft) async throws -> Book
    var setStatus: @Sendable (_ id: String, ReadingStatus) async throws -> Book
    var rate: @Sendable (_ id: String, _ stars: Int) async throws -> Book
    /// The corrected facts and, when it moved, the rating, in one request.
    var save: @Sendable (_ id: String, BookCorrection, _ rating: Int??) async throws -> Book?
    var refresh: @Sendable (_ id: String) async throws -> Book
    /// A shelf book's description, asked when its page first opens.
    var describe: @Sendable (_ id: String) async throws -> Book
    var setFavorite: @Sendable (_ id: String, Bool) async throws -> Book
    var setRecommendation: @Sendable (_ id: String, BookRecommendation?) async throws -> Book
    var setNote: @Sendable (_ id: String, String?) async throws -> Book
    var setHidden: @Sendable (_ id: String, Bool) async throws -> Book
    var delete: @Sendable (_ id: String) async throws -> Void
    /// The subgenres and saga names the reader already used, offered as they type.
    var vocabulary: @Sendable () async throws -> BookVocabulary
    /// The subgenres alone, lighter than the whole vocabulary.
    var subgenres: @Sendable () async throws -> [String]
    var offer: @Sendable (_ bookId: String) async throws -> EditionOffer?
    var awaitEdition: @Sendable (_ bookId: String, ReleaseFormat) async throws -> AwaitedEdition
    var stopAwaiting: @Sendable (_ editionId: String) async throws -> Void
}

extension BookClient {
    static let live = BookClient(
        book: { try await BookAPI.book(id: $0) },
        add: { try await BookAPI.add($0) },
        setStatus: { try await BookAPI.setStatus(id: $0, status: $1) },
        rate: { try await BookAPI.rate(id: $0, stars: $1) },
        save: { try await BookAPI.save(id: $0, correction: $1, rating: $2) },
        refresh: { try await BookAPI.refresh(id: $0) },
        describe: { try await BookAPI.describe(id: $0) },
        setFavorite: { try await BookAPI.setFavorite(id: $0, favorite: $1) },
        setRecommendation: { try await BookAPI.setRecommendation(id: $0, recommendation: $1) },
        setNote: { try await BookAPI.setNote(id: $0, note: $1) },
        setHidden: { try await BookAPI.setHidden(id: $0, hidden: $1) },
        delete: { try await BookAPI.delete(id: $0) },
        vocabulary: { try await BookAPI.vocabulary() },
        subgenres: { try await BookAPI.subgenres() },
        offer: { try await AwaitedAPI.offer(bookId: $0) },
        awaitEdition: { try await AwaitedAPI.awaitEdition(bookId: $0, format: $1) },
        stopAwaiting: { try await AwaitedAPI.stop(id: $0) }
    )

    /// Answers with `Book.preview`, the write applied, and accepts every call.
    static let preview = BookClient(
        book: { _ in .preview },
        add: { _ in .preview },
        setStatus: { _, status in
            var book = Book.preview
            book.status = status
            return book
        },
        rate: { _, stars in
            var book = Book.preview
            book.rating = stars
            return book
        },
        save: { _, _, _ in .preview },
        refresh: { _ in .preview },
        describe: { _ in .preview },
        setFavorite: { _, favorite in
            var book = Book.preview
            book.favorite = favorite
            return book
        },
        setRecommendation: { _, recommendation in
            var book = Book.preview
            book.recommendation = recommendation
            return book
        },
        setNote: { _, note in
            var book = Book.preview
            book.note = note
            return book
        },
        setHidden: { _, hidden in
            var book = Book.preview
            book.hidden = hidden
            return book
        },
        delete: { _ in },
        vocabulary: { (["Space opera", "Cyberpunk"], ["Fondation", "Dune"]) },
        subgenres: { ["Space opera", "Cyberpunk"] },
        offer: { _ in EditionOffer() },
        awaitEdition: { _, format in .pending(format: format, of: .preview) },
        stopAwaiting: { _ in }
    )
}
