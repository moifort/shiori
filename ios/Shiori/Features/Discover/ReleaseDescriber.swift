import SwiftUI

/// Asks the server to describe a release when its page opens, and keeps the
/// release it answers for the page to draw: the same record its list showed,
/// completed. A release described already is not asked again. A page that
/// could not have it described — the allowance used up, or the model failing —
/// stays the release it opened as.
@MainActor
@Observable
final class ReleaseDescriber {
    init(release: Release, describe: @escaping @Sendable () async throws -> Release) {
        self.release = release
        self.describeRelease = describe
    }

    private let describeRelease: @Sendable () async throws -> Release
    /// The release as the page draws it: the list's, then the server's answer.
    private(set) var release: Release
    /// The AI is writing the description, and has been for long enough to be
    /// worth saying: a page answered from the server's cache in a blink never
    /// shows it, where announcing it on every opening made the bar flash.
    private(set) var isDescribing = false
    private var inFlight = false

    /// How long a call may run before the AI is said to be at work. A cached
    /// answer is back well within it; a model call never is.
    private static let grace: Duration = .milliseconds(400)

    func describe() async {
        guard !release.described, !inFlight else { return }
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
            let answered = try await describeRelease()
            withAnimation(.smooth) { release = answered }
        } catch {
            guard !isCancellation(error), (error as? APIError)?.domainCode != "QUOTA_EXHAUSTED" else { return }
            _ = reportError(error)
        }
    }
}
