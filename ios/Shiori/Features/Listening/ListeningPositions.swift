import Foundation

/// Where the reader stopped in each Audible title, kept on the iPhone before it
/// is sent to Audible: a position saved with no network waits here and goes
/// once the network is back, and a downloaded title resumes from it offline.
struct ListeningPositions {
    struct Entry: Codable, Equatable {
        let position: TimeInterval
        let contentReference: String
        let savedAt: Date
        /// Not yet on Audible.
        var isPending: Bool
    }

    private let defaults: UserDefaults
    private static let key = "audible.positions"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func entry(_ asin: String) -> Entry? { all()[asin] }

    /// The positions still to send to Audible.
    func pending() -> [String: Entry] { all().filter(\.value.isPending) }

    func record(_ asin: String, at position: TimeInterval, contentReference: String, now: Date = .now) {
        var entries = all()
        entries[asin] = Entry(position: position, contentReference: contentReference, savedAt: now, isPending: true)
        write(entries)
    }

    /// Audible has it: the entry stays, for an offline resume, but no longer waits.
    func markSent(_ asin: String, savedAt: Date) {
        var entries = all()
        guard entries[asin]?.savedAt == savedAt else { return }
        entries[asin]?.isPending = false
        write(entries)
    }

    func forget(_ asin: String) {
        var entries = all()
        entries[asin] = nil
        write(entries)
    }

    /// Where to resume: the later of what Audible holds — another player may
    /// have gone on since — and what this iPhone kept.
    static func resume(
        audible: TimeInterval?,
        savedAt audibleSavedAt: Date?,
        local: Entry?
    ) -> TimeInterval? {
        guard let local else { return audible }
        guard let audible else { return local.position }
        guard let audibleSavedAt else { return local.isPending ? local.position : audible }
        return local.savedAt > audibleSavedAt ? local.position : audible
    }

    private func all() -> [String: Entry] {
        guard let data = defaults.data(forKey: Self.key),
              let entries = try? JSONDecoder().decode([String: Entry].self, from: data)
        else { return [:] }
        return entries
    }

    private func write(_ entries: [String: Entry]) {
        defaults.set(try? JSONEncoder().encode(entries), forKey: Self.key)
    }
}
