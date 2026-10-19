import Foundation

/// The books whose page the reader opened last, newest first, from anywhere in
/// the app: what the search offers before a word is typed. Ids alone, kept on
/// the device; the search draws them from its index, so a book deleted since
/// simply drops out.
struct RecentlyViewed: Sendable {
    static let limit = 10

    private let key: String
    private let defaults: @Sendable () -> UserDefaults

    init(key: String = "recently-viewed-books", defaults: @escaping @Sendable () -> UserDefaults = { .standard }) {
        self.key = key
        self.defaults = defaults
    }

    var ids: [String] { defaults().stringArray(forKey: key) ?? [] }

    /// Put a book first, once; the oldest falls off past the limit.
    func remember(_ id: String) {
        defaults().set(Array(([id] + ids.filter { $0 != id }).prefix(Self.limit)), forKey: key)
    }

    func clear() {
        defaults().removeObject(forKey: key)
    }
}
