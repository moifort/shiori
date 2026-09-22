import Foundation

/// An Audible pass that outlives the screen that asked for it. Onboarding
/// starts one right after the Amazon sign-in and walks the reader straight
/// into the app; the dashboard's preparation screen waits on it, then its
/// leading spinner shows it running until the library has landed.
///
/// One at a time, app-wide: a second start while a pass runs does nothing.
@MainActor
@Observable
final class AudibleBackgroundSync {
    static let shared = AudibleBackgroundSync()

    private(set) var isSyncing = false
    /// What went wrong with the last pass, for the dashboard to say once.
    var errorMessage: String?

    private init() {}

    /// Runs the pass now. On a fresh connection it catalogues the whole
    /// library; every list refreshes itself when the mutation lands.
    func start() {
        guard !isSyncing else { return }
        isSyncing = true
        errorMessage = nil
        Task {
            defer { isSyncing = false }
            do {
                _ = try await ImportAPI.syncNow()
            } catch {
                errorMessage = reportError(error)
            }
        }
    }
}
