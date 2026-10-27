import Foundation

/// A narrator as the Library tab's rail draws them, under the authors: their
/// face, else their initials, and their name.
struct NarratorRow: Identifiable, Codable, Hashable, Sendable, PortraitPerson {
    let key: String
    var id: String { key }
    /// The spelling most of the reader's recordings use.
    let name: String
    /// Their photograph, once somebody opened their page and found one.
    var portraitURL: URL?

    /// The first letter of the first and last words, as an author's.
    var initials: String {
        let words = name.split(separator: " ")
        let ends = words.count > 1 ? [words.first, words.last] : [words.first]
        return ends.compactMap { $0?.first }.map(String.init).joined().uppercased()
    }
}
