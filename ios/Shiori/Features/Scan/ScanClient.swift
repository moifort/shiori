import Foundation

/// Everything the scan flows ask of the server, as closures: `.live` goes
/// through the APIs, `.preview` answers from fixtures, and a test builds the
/// one it needs inline.
struct ScanClient: Sendable {
    var scan: @Sendable (_ jpeg: Data) async throws -> ScannedBook
    var lookUpLink: @Sendable (String) async throws -> ScannedBook
    var lookUpTitle: @Sendable (String) async throws -> ScannedBook
    /// The books a typed title may name, as the reader types it.
    var searchTitle: @Sendable (String) async throws -> [TitleCandidate]
    var add: @Sendable (BookDraft) async throws -> Book
    var update: @Sendable (_ id: String, BookCorrection) async throws -> Book
    var rate: @Sendable (_ id: String, _ stars: Int) async throws -> Book
    var setFavorite: @Sendable (_ id: String, Bool) async throws -> Book
    /// The editions in the app's language a book in this language and format
    /// may be awaited in.
    var awaitableFormats: @Sendable (BookLanguage, BookFormat) async throws -> [ReleaseFormat]
    var awaitScanned: @Sendable (BookDraft, ReleaseFormat) async throws -> Void
    var vocabulary: @Sendable () async throws -> BookVocabulary
    var subgenres: @Sendable () async throws -> [String]
    var detectShelf: @Sendable (_ jpeg: Data) async throws -> [DetectedBook]
    var describeDetected: @Sendable (DetectedBook) async throws -> ScannedBook
    /// Scans left, month and granted together; nil when unknown.
    var remainingScans: @Sendable () async -> Int?
}

extension ScanClient {
    static let live = ScanClient(
        scan: { try await ScanAPI.scan(jpeg: $0) },
        lookUpLink: { try await ScanAPI.lookUp(link: $0) },
        lookUpTitle: { try await ScanAPI.lookUp(title: $0) },
        searchTitle: { try await ScanAPI.searchTitle($0) },
        add: { try await BookAPI.add($0) },
        update: { try await BookAPI.update(id: $0, correction: $1) },
        rate: { try await BookAPI.rate(id: $0, stars: $1) },
        setFavorite: { try await BookAPI.setFavorite(id: $0, favorite: $1) },
        awaitableFormats: { try await AwaitedAPI.formats(language: $0, format: $1) },
        awaitScanned: { _ = try await AwaitedAPI.awaitScanned($0, format: $1) },
        vocabulary: { try await BookAPI.vocabulary() },
        subgenres: { try await BookAPI.subgenres() },
        detectShelf: { try await ShelfAPI.detect(jpeg: $0) },
        describeDetected: { try await ShelfAPI.describe($0) },
        remainingScans: { (try? await SubscriptionAPI.quota())?.totalRemaining }
    )
}

#if DEBUG
extension ScanClient {
    /// Recognises Dune whatever is sent, adds it, and accepts every write.
    static let preview = ScanClient(
        scan: { _ in .preview },
        lookUpLink: { _ in .preview },
        lookUpTitle: { _ in .preview },
        searchTitle: { _ in [] },
        add: { _ in .preview },
        update: { _, _ in .preview },
        rate: { _, stars in
            var book = Book.preview
            book.rating = stars
            return book
        },
        setFavorite: { _, favorite in
            var book = Book.preview
            book.favorite = favorite
            return book
        },
        awaitableFormats: { _, _ in [.audiobook] },
        awaitScanned: { _, _ in },
        vocabulary: { ([], []) },
        subgenres: { [] },
        detectShelf: { _ in ShelfImportFixtures.books },
        describeDetected: { _ in .preview },
        remainingScans: { 94 }
    )
}

extension ScannedBook {
    static let preview = ScannedBook(
        recognized: true, title: "Dune", authors: ["Frank Herbert"], genre: .scienceFiction
    )
}
#endif
