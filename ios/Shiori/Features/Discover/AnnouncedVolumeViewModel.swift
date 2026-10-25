import Foundation

/// A volume announced or just out: its description, asked for when its page
/// opens, and its addition to the pile.
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
    /// Why the addition failed, for the alert; nil once read.
    var addFailed: String?

    /// The book once described, or as the look on the web knows it until then.
    var shown: Book { opened.book.described(by: describer.description) }
    var isDescribing: Bool { describer.isDescribing }

    func describe() async { await describer.describe(opened.seed) }

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
