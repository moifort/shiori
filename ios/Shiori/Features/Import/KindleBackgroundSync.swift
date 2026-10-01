import Foundation

/// A Kindle pass that outlives the screen that asked for it: onboarding starts
/// one right after the Amazon sign-in and walks the reader straight into the
/// app, and the preparation screen waits on it as it waits on Audible's.
///
/// One at a time, app-wide: a second start while a pass runs does nothing.
@MainActor
@Observable
final class KindleBackgroundSync {
    static let shared = KindleBackgroundSync()

    private(set) var isSyncing = false
    /// What went wrong with the last pass, for the dashboard to say once.
    var errorMessage: String?

    private init() {}

    /// Runs the pass now. On a fresh connection it catalogues the whole library.
    func start() {
        guard !isSyncing else { return }
        isSyncing = true
        errorMessage = nil
        Task {
            defer { isSyncing = false }
            do {
                _ = try await KindleAPI.syncNow()
            } catch {
                errorMessage = reportError(error)
            }
        }
    }
}
