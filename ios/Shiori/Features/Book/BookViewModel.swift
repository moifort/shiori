import Foundation
import SwiftUI

/// Owns one book's screen. Every mutation returns the whole record, so the
/// model replaces its book wholesale rather than patching the field it asked
/// about — rating a book also marks it read, and only the server's answer knows
/// the full consequence.
@MainActor
@Observable
final class BookViewModel {
    private(set) var book: Book?
    private(set) var isLoading = true
    private(set) var errorMessage: String?
    /// Set while a mutation is in flight, so the screen can disable its controls
    /// without blanking the content underneath.
    private(set) var isSaving = false
    /// The covers the picker offers: nil while they are sought.
    private(set) var coverChoices: [CoverChoice]?
    /// Why the covers could not be sought, said in the picker.
    private(set) var coverChoicesFailed: String?
    /// Set while a book added from a shelf photo is described, on its first
    /// opening: the page stays readable and usable, and says so in its bar.
    private(set) var isDescribing = false

    /// What the page offers to await in the app's language, and what it awaits.
    private(set) var offer = EditionOffer()
    /// The volumes of its saga, held or lacking, for the row on its page.
    private(set) var sagaVolumes: [SeriesStripItem] = []
    /// An await refused, said in its own alert.
    var awaitFailed: String?

    private let bookId: String
    private let client: BookClient
    /// The awaits sent and not answered yet, by format: the page already shows
    /// them, so giving one up waits for the server's id.
    private var awaiting: [ReleaseFormat: Task<AwaitedEdition?, Never>] = [:]

    init(bookId: String, client: BookClient) {
        self.bookId = bookId
        self.client = client
    }

    /// The book alone: its saga's catalogue is the series screen's business,
    /// one tap away, and reading it here cost a catalogue call per opening.
    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            book = try await client.book(bookId)
        } catch {
            errorMessage = reportError(error)
        }
        isLoading = false
    }

    /// The volumes of the book's saga, after the book: the page draws without
    /// them, and a failure leaves the row out rather than the page. The ones
    /// the reader lacks come from a catalogue already built, never from a
    /// first build, which is a model call.
    func loadSagaVolumes() async {
        guard let series = book?.series else {
            sagaVolumes = []
            return
        }
        guard let volumes = try? await client.sagaVolumes(series.id, book?.language) else { return }
        withAnimation(.snappy) { sagaVolumes = volumes }
    }

    /// Describes a book added from a shelf photo, the first time its page
    /// opens. Free, and silent when it fails: the page keeps what the spine
    /// gave, and the next opening asks again. True when the book changed, for
    /// the list behind the page to follow.
    func describeIfAwaiting() async -> Bool {
        guard book?.awaitingDescription == true else { return false }
        isDescribing = true
        defer { isDescribing = false }
        do {
            let described = try await client.describe(bookId)
            withAnimation(.snappy) { book = described }
            return true
        } catch {
            _ = reportError(error)
            return false
        }
    }

    func setStatus(_ status: ReadingStatus) async {
        await mutate { [client, bookId] in try await client.setStatus(bookId, status) }
    }

    /// Records the page reached, then moves the book on when the reader said
    /// so in the same sheet: a book given up keeps where they stopped. False
    /// when a call failed, so the sheet stays open.
    func recordPage(_ page: Int?, then status: ReadingStatus? = nil) async -> Bool {
        errorMessage = nil
        if let page { await mutate { [client, bookId] in try await client.recordPage(bookId, page) } }
        if errorMessage == nil, let status { await setStatus(status) }
        return errorMessage == nil
    }

    func rate(_ stars: Double) async {
        await mutate { [client, bookId] in try await client.rate(bookId, stars) }
    }

    /// Saves the edit form: the corrected facts first, then the rating when it
    /// moved. Two calls, because rating is its own mutation with its own rule —
    /// it marks the book read — and the record the second one returns carries
    /// both changes. Returns false when a call failed, so the form stays open.
    func save(_ correction: BookCorrection, rating: Double?) async -> Bool {
        guard let book else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            // One request for the whole sheet: the stars ride the correction,
            // and only when they changed.
            let saved = try await client.save(bookId, correction, rating != book.rating ? .some(rating) : .none)
            if let saved { self.book = saved }
            return true
        } catch {
            errorMessage = reportError(error)
            return false
        }
    }

    /// Seeks the covers the reader may pick, afresh each time the picker
    /// opens: a source may have found one since.
    func loadCoverChoices() async {
        coverChoices = nil
        coverChoicesFailed = nil
        do {
            coverChoices = try await client.coverChoices(bookId)
        } catch {
            coverChoicesFailed = reportError(error)
        }
    }

    /// Draws the book with the cover picked: the image, or the scan photo.
    /// Returns false when the call failed, so the picker stays open.
    func chooseCover(_ choice: CoverChoice) async -> Bool {
        isSaving = true
        defer { isSaving = false }
        do {
            let chosen = try await client.chooseCover(bookId, choice.source == .photo ? nil : choice.url)
            withAnimation(.smooth) { book = chosen }
            return true
        } catch let error as APIError where error.domainCode == "COVER_NOT_AN_IMAGE" {
            // The link to a shop's page, pasted for its cover: the reader's
            // slip, nothing for Sentry.
            errorMessage = String(localized: "Cette adresse mène à une page, pas à une image. Ouvrez l'image de la couverture seule, puis copiez son adresse.")
            return false
        } catch {
            errorMessage = reportError(error)
            return false
        }
    }

    func setFavorite(_ favorite: Bool) async {
        await mutate { [client, bookId] in try await client.setFavorite(bookId, favorite) }
    }

    /// Returns false when the call failed, so the sheet stays open with what
    /// the reader typed.
    func setRecommendation(_ recommendation: BookRecommendation?) async -> Bool {
        isSaving = true
        defer { isSaving = false }
        do {
            book = try await client.setRecommendation(bookId, recommendation)
            return true
        } catch {
            errorMessage = reportError(error)
            return false
        }
    }

    /// Returns false when the call failed, so the sheet stays open with what
    /// the reader typed.
    func setNote(_ note: String?) async -> Bool {
        isSaving = true
        defer { isSaving = false }
        do {
            book = try await client.setNote(bookId, note)
            return true
        } catch {
            errorMessage = reportError(error)
            return false
        }
    }

    func setHidden(_ hidden: Bool) async {
        await mutate { [client, bookId] in try await client.setHidden(bookId, hidden) }
    }

    func delete() async -> Bool {
        isSaving = true
        defer { isSaving = false }
        do {
            try await client.delete(bookId)
            return true
        } catch {
            errorMessage = reportError(error)
            return false
        }
    }

    private func mutate(_ operation: @escaping @Sendable () async throws -> Book) async {
        isSaving = true
        defer { isSaving = false }
        do {
            let answer = try await operation()
            // A write made while the book was being described may answer with
            // the record from before the description: read it again rather than
            // show the spine alone.
            book = answer.awaitingDescription && book?.awaitingDescription == false
                ? (try? await client.book(bookId)) ?? answer
                : answer
        } catch {
            errorMessage = reportError(error)
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    // MARK: - Awaited editions

    func loadOffer() async {
        do {
            offer = try await client.offer(bookId) ?? EditionOffer()
        } catch {
            _ = reportError(error)
        }
    }

    /// Awaits the book's edition in the app's language. The page shows it
    /// awaited at once, with no loader: the server looks it up on the web
    /// behind, and its answer replaces the line when it comes.
    func awaitEdition(_ format: ReleaseFormat) {
        guard let book else { return }
        let pending = AwaitedEdition.pending(format: format, of: book)
        offer.awaited.append(pending)
        let (client, bookId) = (client, bookId)
        awaiting[format] = Task {
            defer { awaiting[format] = nil }
            do {
                let edition = try await client.awaitEdition(bookId, format)
                // Unless the reader gave it up meanwhile.
                if let index = offer.awaited.firstIndex(where: { $0.id == pending.id }) {
                    offer.awaited[index] = edition
                }
                return edition
            } catch {
                offer.awaited.removeAll { $0.id == pending.id }
                awaitFailed = reportError(error)
                return nil
            }
        }
    }

    func stopAwaiting(_ edition: AwaitedEdition) async {
        var edition = edition
        // Given up before the server answered: stopped once it has.
        if let pending = awaiting[edition.format] {
            offer.awaited.removeAll { $0.id == edition.id }
            guard let answered = await pending.value else { return }
            edition = answered
        }
        do {
            try await client.stopAwaiting(edition.id)
            offer.awaited.removeAll { $0.id == edition.id }
        } catch {
            awaitFailed = reportError(error)
        }
    }
}
