import SwiftUI

/// A volume announced or just out: its description, asked for when its page
/// opens, its saga's row, the saga's alerts, and its addition to the pile.
@MainActor
@Observable
final class AnnouncedVolumeViewModel {
    init(opened: DiscoveryVolume, client: DiscoverClient) {
        self.opened = opened
        self.client = client
        let item = ReleaseItem.sagaVolume(seriesId: opened.saga.series.seriesId, number: opened.volume.number)
        describer = ReleaseDescriber(release: opened.volume.release) { try await client.describe(item) }
    }

    let opened: DiscoveryVolume
    private let client: DiscoverClient
    private let describer: ReleaseDescriber

    private(set) var added = false
    /// What the "+" made of the volume, said in its capsule.
    private(set) var taken: TakenState?
    /// On the wishlist, from "Envies".
    private(set) var isWished = false
    /// Bumped on each refusal: the hero's buttons shake.
    private(set) var refusals = 0
    /// The book put on the shelf and the wish made here, which a second tap
    /// takes back.
    private var bookAdded: String?
    private var wishId: String?
    /// Whether the saga alerts on its volumes' days: it is followed, or the
    /// volume would not be shown. Turned at once on a tap, the call made
    /// behind it, as on the saga's page.
    private(set) var isFollowed = true
    /// The saga's volumes, held or lacking, for the row on the page.
    private(set) var sagaVolumes: [SeriesStripItem] = []
    /// Why the addition failed, for the alert; nil once read.
    var addFailed: String?

    /// The volume as its list drew it, then as the server described it.
    var shown: Book { opened.book(of: describer.release) }
    var isDescribing: Bool { describer.isDescribing }
    /// The release the page shows: its cover is picked for every reader.
    var releaseKey: String { describer.release.key }

    /// The cover picked for it, drawn at once.
    func drawCover(_ url: URL) { describer.drawCover(url) }

    func describe() async { await describer.describe() }

    /// The saga's row, read off the catalogue already built: it never pays
    /// for one. Nothing when it fails, the page whole without it.
    func loadSaga() async {
        let series = opened.saga.series
        guard let volumes = try? await client.sagaVolumes(series.seriesId, series.language) else { return }
        withAnimation(.snappy) { sagaVolumes = volumes }
    }

    /// The bell turns at once; a refusal turns it back.
    func toggleFollowed() async {
        let followed = !isFollowed
        isFollowed = followed
        do {
            try await client.setSagaFollowed(opened.saga.series.seriesId, followed)
        } catch {
            _ = reportError(error)
            if isFollowed == followed { isFollowed = !followed }
        }
    }

    /// Onto the pile, filed in its saga at its number, or read already, or
    /// on the wishlist. A recording is best put on the pile through the
    /// reader's Audible account: it keeps its link to the title, as an import
    /// does. Without one, or when Audible sells none, it is added from its
    /// page, as a printed volume is.
    func add(_ addition: UnownedBookAddition = .pile) async {
        let series = opened.saga.series
        if addition == .wishlist {
            await toggleWish()
            return
        }
        let state: TakenState = addition == .read ? .read(isAudio: series.isAudio) : .toRead(isAudio: series.isAudio)
        if addition == .pile, series.isAudio {
            do {
                bookAdded = try await client.addAudibleVolume(series.seriesId, opened.volume.number)
                took(state)
                return
            } catch {
                let code = (error as? APIError)?.domainCode
                if code != "NOT_FOUND" && code != "AUDIBLE_NOT_CONNECTED" { _ = reportError(error) }
            }
        }
        do {
            var draft = opened.draft(from: shown)
            if addition == .read { draft.status = .read }
            bookAdded = try await client.addSuggestion(draft)
            took(state)
        } catch {
            refusals += 1
            addFailed = reportError(error)
        }
    }

    /// The capsule pressed again: the volume leaves the shelf.
    func undoAdd() async {
        do {
            if let bookAdded { try await client.deleteBook(bookAdded) }
            bookAdded = nil
            taken = nil
            added = false
        } catch {
            refusals += 1
            addFailed = reportError(error)
        }
    }

    /// "Envies": onto the wishlist, or off it again.
    func toggleWish() async {
        do {
            if let wishId {
                try await client.removeWish(wishId)
                self.wishId = nil
                isWished = false
            } else {
                wishId = try await client.wish(opened.draft(from: shown), .discovery, nil)
                isWished = true
            }
        } catch {
            refusals += 1
            addFailed = reportError(error)
        }
    }

    private func took(_ state: TakenState) {
        taken = state
        added = true
    }
}
