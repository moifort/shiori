import SwiftUI

/// Everything an announced volume's page can ask for.
enum AnnouncedVolumeAction {
    case close
    /// On the pile, filed in its saga at its number.
    case add
    case openSaga
    /// The saga's alerts on or off, from the bell.
    case toggleFollowed
    /// One of the reader's own volumes in the saga's row.
    case openVolume(Book)
}

/// A volume announced, opened from "Nouveautés", Découvrir or its saga, drawn
/// as a book to come is (`UpcomingBookPage`): the reader's own book page,
/// its day pinned in the hero's corner. It opens at once on what the look on
/// the web found, then fills in as a book's page — summary, genre, pages,
/// publisher, narrators — once the model described it, for every reader at
/// once, so it spends no scan. The bell is the saga's: it alerts on every
/// volume's day.
struct AnnouncedVolumePage: View {
    let opened: DiscoveryVolume
    /// The book once described, or as the look on the web knows it until then.
    let shown: Book
    let isDescribing: Bool
    let added: Bool
    /// Whether the saga's row leads to its page. Not when it was opened from
    /// the saga's page, which is right under it: the row leads back.
    let linksToSaga: Bool
    var isFollowed = true
    var sagaVolumes: [SeriesStripItem] = []
    /// False when the page is pushed: Back closes it, not a Close button.
    var showsClose = true
    let onAction: (AnnouncedVolumeAction) async -> Void

    var body: some View {
        UpcomingBookPage(
            book: shown,
            releaseDate: opened.volume.date,
            isDescribing: isDescribing,
            store: store,
            isAlerted: isFollowed,
            state: state,
            isAdded: added,
            sagaName: opened.saga.series.name,
            sagaVolumes: sagaVolumes,
            showsClose: showsClose,
            onClose: { act(.close) },
            onAdd: { await onAction(.add) },
            onToggleBell: { act(.toggleFollowed) },
            onOpenSaga: { act(linksToSaga ? .openSaga : .close) },
            onOpenVolume: { act(.openVolume($0)) }
        )
    }

    /// Closing and opening the saga: nothing to wait for.
    private func act(_ action: AnnouncedVolumeAction) {
        Task { await onAction(action) }
    }

    /// Where it is ordered: its recording on Audible for a saga heard, once
    /// Audible confirmed it; Amazon for anything else.
    private var store: UpcomingStore? {
        let series = opened.saga.series
        if series.isAudio {
            return opened.volume.audibleURL.map { UpcomingStore(url: $0, isAudible: true) }
        }
        return opened.volume.amazonURL(author: series.author ?? "").map { UpcomingStore(url: $0, isAudible: false) }
    }

    /// Said on the detail line only when the calendar leaf in the corner does
    /// not say it already: once added, once out, or with no date yet.
    private var state: BookState? {
        if added { return .addedToPile }
        if let date = opened.volume.date, ReleaseDateText.isUpcoming(date) { return nil }
        return .release(opened.volume.date)
    }
}

#Preview("Announced") {
    NavigationStack {
        AnnouncedVolumePage(
            opened: .preview,
            shown: DiscoveryVolume.preview.book,
            isDescribing: true,
            added: false,
            linksToSaga: true
        ) { _ in }
    }
}

#Preview("Described, added") {
    NavigationStack {
        AnnouncedVolumePage(
            opened: .preview,
            shown: DiscoveryVolume.preview.book.described(by: .preview),
            isDescribing: false,
            added: true,
            linksToSaga: true,
            sagaVolumes: [
                .missing(key: "dcc-7", number: 7, title: "La Parade de Mondes", forthcoming: false),
                .missing(key: "dcc-8", number: 8, title: "Le Livre du Carnage", forthcoming: true, date: "2026-11-05"),
            ]
        ) { _ in }
    }
}
