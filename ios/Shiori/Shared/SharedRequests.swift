import Foundation

/// Identical requests asked while one is on its way share its answer rather
/// than each going to the server. As the app opens, the Home, Library and
/// Découvrir tabs each ask for the editions awaited and the sagas' releases at
/// the same moment: the server answered every one of them apart, and the burst
/// slowed them all down.
///
/// Only requests in flight are shared: one asked after the answer came back
/// goes to the server again, so nothing is ever served stale. A caller whose
/// task is cancelled gets a cancellation; the request itself is called off
/// only once every caller sharing it has gone.
final class SharedRequests: @unchecked Sendable {
    static let shared = SharedRequests()

    /// Mutated under the lock only.
    private final class Entry: @unchecked Sendable {
        let id = UUID()
        var task: Task<any Sendable, any Error>?
        var waiters = 1
    }

    private let lock = NSLock()
    private var running: [AnyHashable: Entry] = [:]

    func run<Value: Sendable>(
        _ key: AnyHashable,
        _ request: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        let entry = lock.withLock {
            if let joined = running[key] {
                joined.waiters += 1
                return joined
            }
            let started = Entry()
            let id = started.id
            // Under the lock: the task's own removal waits until it is listed.
            started.task = Task {
                defer { self.finish(id) }
                return try await request() as any Sendable
            }
            running[key] = started
            return started
        }
        return try await withTaskCancellationHandler {
            guard let task = entry.task else { throw CancellationError() }
            let value = try await task.value
            // Called off while others still waited: the answer is theirs.
            try Task.checkCancellation()
            guard let typed = value as? Value else { throw APIError.invalidResponse }
            return typed
        } onCancel: {
            leave(entry)
        }
    }

    /// One caller fewer: the last one gone calls the request off, and a caller
    /// arriving after it starts a new one rather than joining a cancelled task.
    private func leave(_ entry: Entry) {
        let abandoned = lock.withLock {
            entry.waiters -= 1
            guard entry.waiters == 0 else { return false }
            forget(entry.id)
            return true
        }
        if abandoned { entry.task?.cancel() }
    }

    private func finish(_ id: UUID) {
        lock.withLock { forget(id) }
    }

    /// Under the lock. By identity: the key, an `AnyHashable`, cannot travel
    /// into the request's task.
    private func forget(_ id: UUID) {
        running = running.filter { $0.value.id != id }
    }
}
