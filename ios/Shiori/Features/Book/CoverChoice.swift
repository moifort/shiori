import Foundation

/// A cover the reader may pick for a book, as the cover picker offers it.
struct CoverChoice: Identifiable, Hashable, Sendable {
    enum Source: Hashable, Sendable {
        /// The cover Amazon shows for the Kindle title.
        case kindle
        /// The photo taken when the book was scanned.
        case photo
        case amazon
        case openLibrary
        /// The cover of another edition of the work, in the same language.
        case otherEdition
        /// An image no known source serves: most often one pasted.
        case web
    }

    let source: Source
    let url: URL
    /// The cover the book is drawn with now.
    let isCurrent: Bool

    var id: URL { url }
}

extension CoverChoice {
    /// What the picker offers `Book.preview`: its own cover, the Kindle one,
    /// Amazon's for its ISBN and another French edition.
    static let previews: [CoverChoice] = [
        CoverChoice(
            source: .openLibrary,
            url: URL(string: "https://covers.openlibrary.org/b/isbn/9782352942832-L.jpg?default=false")!,
            isCurrent: true
        ),
        CoverChoice(
            source: .kindle,
            url: URL(string: "https://m.media-amazon.com/images/P/2352943558.01._SCLZZZZZZZ_.jpg")!,
            isCurrent: false
        ),
        CoverChoice(
            source: .amazon,
            url: URL(string: "https://m.media-amazon.com/images/P/2352942837.01._SCLZZZZZZZ_.jpg")!,
            isCurrent: false
        ),
        CoverChoice(
            source: .otherEdition,
            url: URL(string: "https://covers.openlibrary.org/b/isbn/9782352943556-L.jpg?default=false")!,
            isCurrent: false
        ),
    ]
}
