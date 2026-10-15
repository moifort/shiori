/// One load of each kind at a time. A screen asks for the same section from
/// several places — its appearance, a change notice, a sheet closing — and
/// each used to start a request of its own, side by side with the one already
/// on its way.
///
/// Asked while that kind is running, a load either rides on it (`again:
/// false`: what is coming is what was wanted) or has it run once more when it
/// ends (`again: true`: a write landed since it set out), however many times
/// it was asked meanwhile.
@MainActor
final class LoadGate<Kind: Hashable> {
    private var running: Set<Kind> = []
    private var stale: Set<Kind> = []

    /// A write landed since the load running for that kind set out: what it
    /// brings back is already behind.
    func isStale(_ kind: Kind) -> Bool { stale.contains(kind) }

    func run(_ kind: Kind, again: Bool, _ load: () async -> Void) async {
        guard running.insert(kind).inserted else {
            if again { stale.insert(kind) }
            return
        }
        defer { running.remove(kind) }
        repeat {
            stale.remove(kind)
            await load()
        } while stale.contains(kind) && !Task.isCancelled
    }
}
