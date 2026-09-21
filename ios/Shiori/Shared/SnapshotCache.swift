import Foundation

/// What a screen showed last time, kept on disk so a relaunch opens on it
/// instead of on a loader. The library, the sagas and the dashboard change
/// slowly: the snapshot written last time is almost always what the server
/// is about to send, and a screen one session old is worth far more than an
/// empty one. The snapshot draws first, the server's answer replaces it a
/// moment later, under a spinner at the top of the screen.
///
/// Every snapshot lives in one folder of the caches directory, which the
/// system may reclaim at will — that is what a cache is for, and losing it
/// costs one loader. The screen decides what goes in: only what it *opens*
/// on, never a filtered state the reader asked for.
struct SnapshotCache<Value: Codable & Sendable>: Sendable {
    /// The file's name, one per screen.
    private let name: String
    /// Bump whenever `Value` changes shape. An older file is then ignored
    /// instead of decoded into something that no longer means the same thing.
    private let version: Int

    init(_ name: String, version: Int) {
        self.name = name
        self.version = version
    }

    private var file: URL {
        SnapshotCaches.folder.appending(path: "\(name).json")
    }

    /// The last snapshot, or `nil` when there is no usable file: a first
    /// launch, a cache the system reclaimed, or a file written by an older shape.
    func read() -> Value? {
        guard let data = try? Data(contentsOf: file),
              let stored = try? JSONDecoder().decode(Stored.self, from: data),
              stored.version == version
        else { return nil }
        return stored.value
    }

    /// Overwrite the snapshot with what is on screen. A failure is swallowed
    /// on purpose: a snapshot that cannot be written costs a loader on the
    /// next launch, nothing more.
    func write(_ value: Value) {
        guard let data = try? JSONEncoder().encode(Stored(version: version, value: value))
        else { return }
        try? FileManager.default.createDirectory(
            at: SnapshotCaches.folder, withIntermediateDirectories: true
        )
        try? data.write(to: file, options: .atomic)
    }

    private struct Stored: Codable {
        let version: Int
        let value: Value
    }
}

/// Forget every screen's snapshot. Called when the session ends: whoever opens
/// the app next must not read the previous account's library before the
/// server has said a word.
enum SnapshotCaches {
    /// The one folder every snapshot lives in, so the session's end is a single delete.
    static var folder: URL {
        URL.cachesDirectory.appending(path: "snapshots", directoryHint: .isDirectory)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: folder)
    }
}
