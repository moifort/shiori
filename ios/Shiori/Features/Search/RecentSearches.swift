import Foundation

/// The last few queries a result was opened from, newest first, kept on the
/// device alone.
struct RecentSearches: Sendable {
    static let limit = 5

    private let key: String
    private let defaults: @Sendable () -> UserDefaults

    init(key: String = "library-search-recents", defaults: @escaping @Sendable () -> UserDefaults = { .standard }) {
        self.key = key
        self.defaults = defaults
    }

    var all: [String] { defaults().stringArray(forKey: key) ?? [] }

    /// Put a query first, once, trimmed; the oldest falls off past the limit.
    func remember(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !SearchText.normalized(trimmed).isEmpty else { return }
        let kept = all.filter { SearchText.normalized($0) != SearchText.normalized(trimmed) }
        defaults().set(Array(([trimmed] + kept).prefix(Self.limit)), forKey: key)
    }

    func clear() {
        defaults().removeObject(forKey: key)
    }
}
