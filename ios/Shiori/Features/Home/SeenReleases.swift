import Foundation

/// The releases the reader marked seen from the home screen's carousel, which
/// no longer puts them forward, kept on the device alone: the newest last,
/// the oldest falling off past the limit, long after the release left the
/// carousel's weeks.
struct SeenReleases: Sendable {
    static let limit = 200

    private let key: String
    private let defaults: @Sendable () -> UserDefaults

    init(key: String = "home-seen-releases", defaults: @escaping @Sendable () -> UserDefaults = { .standard }) {
        self.key = key
        self.defaults = defaults
    }

    var all: Set<HomeRelease.ID> { Set(defaults().stringArray(forKey: key) ?? []) }

    func see(_ id: HomeRelease.ID) {
        let kept = (defaults().stringArray(forKey: key) ?? []).filter { $0 != id }
        defaults().set(Array((kept + [id]).suffix(Self.limit)), forKey: key)
    }

    func unsee(_ id: HomeRelease.ID) {
        defaults().set((defaults().stringArray(forKey: key) ?? []).filter { $0 != id }, forKey: key)
    }
}
