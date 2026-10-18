import SwiftUI

/// Everything an announced volume's page can ask for.
enum AnnouncedVolumeAction {
    case close
    /// On the pile, filed in its saga at its number.
    case add
    case openSaga
}

/// A volume announced, opened as a book opens, drawn as every book page is,
/// when it comes pinned on its cover — orange while announced, green once
/// out — with Audible's tag in its corner for a recording, and the way to its
/// saga where the book page has it. It opens at once on what the look on the
/// web found, then fills in as a book's page — summary, genre, pages,
/// publisher, narrators — once the model described it, for every reader at
/// once, so it spends no scan.
struct AnnouncedVolumePage: View {
    let opened: DiscoveryVolume
    /// The book once described, or as the look on the web knows it until then.
    let shown: Book
    let isDescribing: Bool
    let added: Bool
    /// Whether the page links to its saga.
    let linksToSaga: Bool
    let onAction: (AnnouncedVolumeAction) async -> Void

    var body: some View {
        List {
            BookHeaderSection(
                book: shown,
                state: state,
                releaseDate: opened.volume.date,
                storeLink: opened.volume.audibleURL.map { .init(name: "Audible", url: $0, tint: .audible) },
                actions: .init(openSeries: linksToSaga ? { act(.openSaga) } : nil)
            )
            ReleaseDescriptionSections(isDescribing: isDescribing, synopsis: shown.synopsis)
        }
        .listStyle(.insetGrouped)
        .generatingInBar(isDescribing ? "L'IA complète la fiche" : nil)
        .labelStyle(.row)
        .navigationTitle(Text(verbatim: opened.saga.series.name))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) { act(.close) }
            }
            ToolbarItem(placement: .primaryAction) {
                AsyncToolbarButton(title: "Ajouter à ma pile", systemImage: "plus") { await onAction(.add) }
                    .disabled(added)
                    .accessibilityIdentifier("announced-volume-add")
            }
        }
    }

    /// Closing and opening the saga: nothing to wait for.
    private func act(_ action: AnnouncedVolumeAction) {
        Task { await onAction(action) }
    }

    /// Said under the author only when the calendar leaf in the corner does
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
            linksToSaga: true
        ) { _ in }
    }
}
