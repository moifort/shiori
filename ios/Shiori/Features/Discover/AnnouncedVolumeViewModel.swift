import SwiftUI

/// A volume announced or just out: its description, asked for when its page
/// opens, its saga's row, the saga's alerts, and its addition to the pile.
@MainActor
@Observable
final class AnnouncedVolumeViewModel {
    init(opened: DiscoveryVolume, client: DiscoverClient) {
        self.opened = opened
        self.client = client
        describer = ReleaseDescriber(describe: client.describe)
    }

    let opened: DiscoveryVolume
    private let client: DiscoverClient
    private let describer: ReleaseDescriber

    private(set) var added = false
    /// Whether the saga alerts on its volumes' days: it is followed, or the
    /// volume would not be shown. Turned at once on a tap, the call made
    /// behind it, as on the saga's page.
    private(set) var isFollowed = true
    /// The saga's volumes, held or lacking, for the row on the page.
    private(set) var sagaVolumes: [SeriesStripItem] = []
    /// Why the addition failed, for the alert; nil once read.
    var addFailed: String?

    /// The book once described, or as the look on the web knows it until then.
    var shown: Book { opened.book.described(by: describer.description) }
    var isDescribing: Bool { describer.isDescribing }

    func describe() async { await describer.describe(opened.seed) }

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

    /// Onto the pile, filed in its saga at its number. A recording is best
    /// added through the reader's Audible account: it keeps its link to the
    /// title, as an import does. Without one, or when Audible sells none, it
    /// is added from its page, as a printed volume is.
    func add() async {
        let series = opened.saga.series
        if series.isAudio {
            do {
                try await client.addAudibleVolume(series.seriesId, opened.volume.number)
                added = true
                return
            } catch {
                let code = (error as? APIError)?.domainCode
                if code != "NOT_FOUND" && code != "AUDIBLE_NOT_CONNECTED" { _ = reportError(error) }
            }
        }
        do {
            try await client.addBook(opened.draft(from: shown))
            added = true
        } catch {
            addFailed = reportError(error)
        }
    }
}
