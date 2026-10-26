import Foundation

/// The author a row opens: the key the page is asked by, and the name its
/// title shows while it loads.
struct AuthorDestination: Hashable, Identifiable {
    let key: String
    let name: String
    /// An author a friend loves, offered by Découvrir: the reader may hold
    /// nothing of theirs.
    var isOffered = false
    var id: String { key }

    init(_ author: FollowedAuthor) {
        key = author.key
        name = author.name
    }

    init(key: String, name: String, isOffered: Bool = false) {
        self.key = key
        self.name = name
        self.isOffered = isOffered
    }
}
