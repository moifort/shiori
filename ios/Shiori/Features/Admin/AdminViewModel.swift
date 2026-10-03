import SwiftUI

/// Loads the month's figures for the admin screen.
@MainActor @Observable
final class AdminViewModel {
    private(set) var metrics: AdminMetrics?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            metrics = try await AdminAPI.metrics()
        } catch {
            errorMessage = reportError(error)
        }
    }
}
