import SwiftUI

/// A narrator's page: the reader's recordings in their voice, and the heart.
@MainActor
@Observable
final class NarratorViewModel {
    let key: String
    let name: String

    private(set) var page: NarratorPage?
    private(set) var isLoading = true
    var errorMessage: String?

    private let client: NarratorsClient

    init(key: String, name: String, client: NarratorsClient) {
        self.key = key
        self.name = name
        self.client = client
    }

    var isFavorite: Bool { page?.favorite ?? false }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            // The name always goes along: the server reads it only for a
            // narrator the reader holds nothing of, read on a friend's recording.
            let fresh = try await client.page(key, name)
            withAnimation(page == nil ? nil : .smooth) { page = fresh }
            if fresh == nil { errorMessage = nil }
        } catch {
            guard !isCancellation(error) else { return }
            errorMessage = reportError(error)
        }
    }

    /// Hearts the narrator, or takes the heart back: drawn at once, put back
    /// if the server refused.
    func toggleFavorite() async {
        guard page != nil else { return }
        let wanted = !isFavorite
        page?.favorite = wanted
        do {
            page?.favorite = try await client.setFavorite(key, wanted)
        } catch {
            page?.favorite = !wanted
            guard !isCancellation(error) else { return }
            errorMessage = reportError(error)
        }
    }
}
