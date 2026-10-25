import Foundation

/// Everything a book's screens ask of the server, as closures: `.live` goes
/// through `BookAPI` and `AwaitedAPI`, `.preview` answers from `Book.preview`,
/// and a test builds the one it needs inline.
struct BookClient: Sendable {
    var book: @Sendable (_ id: String) async throws -> Book?
    var add: @Sendable (BookDraft) async throws -> Book
    var setStatus: @Sendable (_ id: String, ReadingStatus) async throws -> Book
    var rate: @Sendable (_ id: String, _ stars: Double) async throws -> Book
    /// The corrected facts and, when it moved, the rating, in one request.
    var save: @Sendable (_ id: String, BookCorrection, _ rating: Double??) async throws -> Book?
    /// The covers the reader may pick, the one drawn now first.
    var coverChoices: @Sendable (_ id: String) async throws -> [CoverChoice]
    /// The cover picked: an image, or the scan photo when the URL is nil.
    var chooseCover: @Sendable (_ id: String, URL?) async throws -> Book
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
    /// The volumes of the book's saga the reader holds, for the row under its
    /// facts. None by default: a test or a preview that draws no saga leaves it.
    var sagaVolumes: @Sendable (_ seriesId: String, BookLanguage?) async throws -> [Book] = { _, _ in [] }
}

extension BookClient {
    static let live = BookClient(
        book: { try await BookAPI.book(id: $0) },
        add: { try await BookAPI.add($0) },
        setStatus: { try await BookAPI.setStatus(id: $0, status: $1) },
        rate: { try await BookAPI.rate(id: $0, stars: $1) },
        save: { try await BookAPI.save(id: $0, correction: $1, rating: $2) },
        coverChoices: { try await BookAPI.coverChoices(id: $0) },
        chooseCover: { try await BookAPI.chooseCover(id: $0, url: $1) },
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
        stopAwaiting: { try await AwaitedAPI.stop(id: $0) },
        sagaVolumes: { try await BookAPI.sagaVolumes(seriesId: $0, language: $1) }
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
        coverChoices: { _ in CoverChoice.previews },
        chooseCover: { _, url in
            var book = Book.preview
            book.coverURL = url ?? book.coverURL
            return book
        },
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
