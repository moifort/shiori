import Foundation

/// The release notes, served by the backend in the reader's language.
@MainActor
@Observable
final class ChangelogViewModel {
    private(set) var entries: [ChangelogEntry] = []
    private(set) var isLoading = true
    private(set) var errorMessage: String?

    private let client: SettingsClient

    init(client: SettingsClient) {
        self.client = client
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            entries = try await client.changelog()
        } catch {
            errorMessage = reportError(error)
        }
        isLoading = false
    }
}
