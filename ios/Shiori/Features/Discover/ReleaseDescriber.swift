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
    private(set) var isDescribing = false

    func describe(_ seed: ReleaseSeed) async {
        guard description == nil, !isDescribing else { return }
        isDescribing = true
        defer { isDescribing = false }
        do {
            let found = try await describeSeed(seed)
            withAnimation(.smooth) { description = found }
        } catch {
            guard !isCancellation(error), (error as? APIError)?.domainCode != "QUOTA_EXHAUSTED" else { return }
            _ = reportError(error)
        }
    }
}
