import SwiftUI

/// Everything an awaited edition's page can ask for.
enum AwaitedEditionAction {
    case close
    /// On the pile, filed in the saga of the reader's copy.
    case add
    /// Given up, once confirmed: the page closes behind it.
    case stopAwaiting
    /// The reader's copy, or another of their volumes, in the saga's row.
    case openVolume(Book)
    case openSaga(String)
}

/// One awaited edition — a translation or a recording of a book the reader
/// holds — opened from "Nouveautés", Découvrir or the book's page, drawn as a
/// book to come is (`UpcomingBookPage`): the reader's own book page, its day
/// pinned in the hero's corner, the saga of their copy under it, their copy
/// ringed. Only what is known is drawn. The bell gives the wait up, asked for
/// twice as a saga's deletion is; the Audible sync brings a recording bought
/// into the library by itself, which ends the wait.
struct AwaitedEditionPage: View {
    let edition: AwaitedEdition
    /// The edition once described, as a book's page draws it.
    let shown: Book
    let isDescribing: Bool
    var added = false
    var sagaVolumes: [SeriesStripItem] = []
    /// False when the page is pushed: Back closes it, not a Close button.
    var showsClose = true
    let onAction: (AwaitedEditionAction) async -> Void

    var body: some View {
        UpcomingBookPage(
            book: shown,
            releaseDate: edition.date,
            isDescribing: isDescribing,
            store: edition.storeURL.map { UpcomingStore(url: $0, isAudible: edition.format == .audiobook) },
            isAlerted: true,
            bellConfirmation: BellConfirmation(
                title: "Ne plus suivre ce livre ?",
                message: "Vous ne serez plus prévenu de sa sortie.",
                action: "Ne plus suivre"
            ),
            state: state,
            isAdded: edition.isAddable ? added : nil,
            leadingTiles: originalTitleTile,
            sagaName: shown.series?.name,
            sagaVolumes: sagaVolumes,
            currentVolumeId: edition.bookId,
            showsClose: showsClose,
            onClose: { act(.close) },
            onAdd: { await onAction(.add) },
            onToggleBell: { act(.stopAwaiting) },
            onOpenSaga: { if let id = shown.series?.id { act(.openSaga(id)) } },
            onOpenVolume: { act(.openVolume($0)) }
        )
    }

    private func act(_ action: AwaitedEditionAction) {
        Task { await onAction(action) }
    }

    /// Said on the detail line only when the calendar leaf does not say it:
    /// once out, or while nothing is announced.
    private var state: BookState? {
        if added { return .addedToPile }
        if edition.state == .announced, let date = edition.date, ReleaseDateText.isUpcoming(date) { return nil }
        return BookState(text: edition.stateLine, tint: edition.stateTint ?? .gray)
    }

    /// Its title in its own language, heading the facts when the edition
    /// translates it.
    private var originalTitleTile: [FactTile] {
        guard edition.title != edition.originalTitle else { return [] }
        return [FactTile(id: "originalTitle", title: "Titre original", value: edition.originalTitle, isWide: true)]
    }
}

#Preview("Describing") {
    NavigationStack {
        AwaitedEditionPage(edition: .preview, shown: AwaitedEdition.preview.cover, isDescribing: true) { _ in }
    }
}

#Preview("Described") {
    NavigationStack {
        AwaitedEditionPage(
            edition: .preview,
            shown: AwaitedEdition.preview.cover.described(by: .preview),
            isDescribing: false
        ) { _ in }
    }
}
