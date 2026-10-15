import SwiftUI

/// Everything an awaited edition's page can ask for.
enum AwaitedEditionAction {
    case close
    /// Given up, once confirmed: the page closes behind it.
    case stopAwaiting
}

/// One awaited edition, opened from Découvrir, drawn as a volume announced
/// is: where it stands pinned on its cover — orange while announced, green
/// once out — with the store's tag in its corner once it sells it, what it is a translation or a recording of, and
/// since when it is watched for. Only what is known is drawn. "Ne plus suivre"
/// sits in the corner, asked for twice as a saga's deletion is. The Audible
/// sync brings a recording bought into the library by itself, which ends the
/// wait.
struct AwaitedEditionPage: View {
    let edition: AwaitedEdition
    /// The edition once described, as a book's page draws it.
    let shown: Book
    let isDescribing: Bool
    let onAction: (AwaitedEditionAction) async -> Void

    @State private var confirmStop = false

    var body: some View {
        List {
            BookHeaderSection(
                book: shown,
                state: edition.pageState,
                releaseDate: edition.announcedDate,
                storeLink: edition.storeURL.map { .init(name: edition.format.storeName, url: $0, tint: edition.format.storeTint) }
            ) {
                if edition.title != edition.originalTitle {
                    LabeledInfoRow(title: "Titre original", value: edition.originalTitle, icon: "character.book.closed")
                }
                if let awaitedAt = edition.awaitedAt {
                    LabeledInfoRow(
                        title: "Suivi depuis le",
                        value: awaitedAt.formatted(date: .abbreviated, time: .omitted),
                        icon: "binoculars"
                    )
                }
            }
            ReleaseDescriptionSections(isDescribing: isDescribing, synopsis: shown.synopsis)
        }
        .listStyle(.insetGrouped)
        .labelStyle(.row)
        .navigationTitle(edition.format.awaitedTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) { act(.close) }
            }
            ToolbarItem(placement: .primaryAction) {
                ToolbarIconButton(title: "Ne plus suivre", systemImage: "bell.slash") {
                    confirmStop = true
                }
                .tint(.red)
                .accessibilityIdentifier("awaited-stop")
                // Attached to the button, as a saga's deletion is: the dialog
                // rises from the control that asked.
                .confirmationDialog(
                    "Ne plus suivre ce livre ?",
                    isPresented: $confirmStop,
                    titleVisibility: .visible
                ) {
                    Button("Ne plus suivre", role: .destructive) { act(.stopAwaiting) }
                        .accessibilityIdentifier("choice-stop-awaiting")
                    Button("Annuler", role: .cancel) {}
                } message: {
                    Text("Vous ne serez plus prévenu de sa sortie.")
                }
            }
        }
    }

    private func act(_ action: AwaitedEditionAction) {
        Task { await onAction(action) }
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
