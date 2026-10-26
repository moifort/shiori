import Foundation

/// What the reader changed on an author in the edit form or the portrait
/// picker. A nil property was not touched and is not sent; `.clear` empties a
/// field the reader deleted.
struct AuthorCorrection: Equatable, Sendable {
    var nationality: BookCorrection.Change<String>?
    var birthYear: BookCorrection.Change<Int>?
    var deathYear: BookCorrection.Change<Int>?
    var biography: BookCorrection.Change<String>?
    /// A face picked among those offered, or an address pasted. Never cleared.
    var portraitURL: URL?

    var isEmpty: Bool { self == AuthorCorrection() }
}

/// A face the reader may give an author, as the portrait picker offers it.
struct PortraitChoice: Identifiable, Hashable, Sendable {
    enum Source: Hashable, Sendable {
        case wikipedia
        case wikidata
        case openLibrary
        /// An image no known source serves: most often one pasted.
        case web
    }

    let source: Source
    let url: URL
    /// The face the author is drawn with now.
    let isCurrent: Bool

    var id: URL { url }
}

extension PortraitChoice {
    static let previews: [PortraitChoice] = [
        PortraitChoice(
            source: .wikipedia,
            url: URL(string: "https://upload.wikimedia.org/wikipedia/commons/7/7f/Robin_Hobb.jpg")!,
            isCurrent: true
        ),
        PortraitChoice(
            source: .openLibrary,
            url: URL(string: "https://covers.openlibrary.org/a/olid/OL25677A-L.jpg")!,
            isCurrent: false
        ),
    ]
}
