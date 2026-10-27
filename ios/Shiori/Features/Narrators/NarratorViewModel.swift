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
    /// The AI is describing a narrator nobody had: the reader's recordings are
    /// on screen meanwhile, and every action at hand.
    private(set) var isCataloguing = false
    /// The faces the portrait picker offers; nil while they are sought.
    private(set) var portraitChoices: [PortraitChoice]?
    private(set) var portraitChoicesFailed: String?

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

    /// Builds the catalogue of a narrator the page found awaiting one: the
    /// recordings stay on screen while the AI writes it, then it slides in.
    func buildCatalogueIfAwaiting() async {
        guard page?.isAwaitingCatalogue == true, !isCataloguing else { return }
        isCataloguing = true
        defer { isCataloguing = false }
        do {
            let built = try await client.catalogue(key, name)
            withAnimation(.smooth) { if let built { page = built } }
        } catch {
            guard !isCancellation(error) else { return }
            _ = reportError(error)
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

    /// The narrator corrected from the edit form or the portrait picker: the
    /// page takes the server's answer. Answers the message to show, or nil
    /// once saved.
    func correct(_ correction: PersonCorrection) async -> String? {
        do {
            if let corrected = try await client.correct(key, correction) {
                withAnimation(.smooth) { page = corrected }
            }
            return nil
        } catch let error as APIError where error.domainCode == "PORTRAIT_NOT_AN_IMAGE" {
            // The link to a page, pasted for its photo: the reader's slip,
            // nothing for Sentry.
            return String(localized: "Cette adresse mène à une page, pas à une image. Ouvrez la photo seule, puis copiez son adresse.")
        } catch {
            return reportError(error)
        }
    }

    /// The faces the portrait picker offers, sought when it opens: nil while
    /// they are, and `portraitChoicesFailed` says why they could not be.
    func loadPortraitChoices() async {
        portraitChoices = nil
        portraitChoicesFailed = nil
        do {
            portraitChoices = try await client.portraitChoices(key)
        } catch {
            guard !isCancellation(error) else { return }
            portraitChoicesFailed = reportError(error)
        }
    }
}
