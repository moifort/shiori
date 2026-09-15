import Foundation

@MainActor
@Observable
final class HomeViewModel {
    private(set) var dashboard: Dashboard?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            dashboard = try await HomeAPI.dashboard()
        } catch {
            // The last dashboard stays on screen: blanking good figures because a
            // refresh failed reads as data loss.
            errorMessage = reportError(error)
        }
        isLoading = false
    }
}
