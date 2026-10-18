import SwiftUI

/// Asks for a shown book's description when its page opens, and keeps it for
/// the page to draw. A page that could not have one — the allowance used up,
/// or the model failing — stays the plain page it opened as.
@MainActor
@Observable
final class ReleaseDescriber {
    init(describe: @escaping @Sendable (ReleaseSeed) async throws -> ReleaseDescription) {
        self.describeSeed = describe
    }

    private let describeSeed: @Sendable (ReleaseSeed) async throws -> ReleaseDescription
    private(set) var description: ReleaseDescription?
    /// The AI is writing the description, and has been for long enough to be
    /// worth saying: a page answered from the server's cache in a blink never
    /// shows it, where announcing it on every opening made the bar flash.
    private(set) var isDescribing = false
    private var inFlight = false

    /// How long a call may run before the AI is said to be at work. A cached
    /// answer is back well within it; a model call never is.
    private static let grace: Duration = .milliseconds(400)

    func describe(_ seed: ReleaseSeed) async {
        guard description == nil, !inFlight else { return }
        inFlight = true
        defer {
            inFlight = false
            isDescribing = false
        }
        let announce = Task { [weak self] in
            try? await Task.sleep(for: Self.grace)
            guard !Task.isCancelled else { return }
            self?.isDescribing = true
        }
        defer { announce.cancel() }
        do {
            let found = try await describeSeed(seed)
            withAnimation(.smooth) { description = found }
        } catch {
            guard !isCancellation(error), (error as? APIError)?.domainCode != "QUOTA_EXHAUSTED" else { return }
            _ = reportError(error)
        }
    }
}
