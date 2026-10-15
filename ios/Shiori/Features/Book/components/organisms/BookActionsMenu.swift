import SwiftUI

/// Everything the "…" menu of a book can ask for.
enum BookMenuAction {
    case edit
    /// The book looked up again on the web.
    case refresh
    case joinSeries
    case recommend
    case awaitEdition(ReleaseFormat)
    case stopAwaiting(AwaitedEdition)
    case setStatus(ReadingStatus)
    case delete
}

/// The "…" in a book's corner. Status and sharing are switched on the page
/// itself, and the series opens from its row: the menu only holds what the
/// page cannot do.
struct BookActionsMenu: View {
    let book: Book
    /// What may be awaited of it in the app's language, and what is.
    let offer: EditionOffer
    let onAction: (BookMenuAction) -> Void

    @State private var confirmDelete = false

    var body: some View {
        Menu {
            Button("Modifier", systemImage: "pencil") {
                onAction(.edit)
            }
            .accessibilityIdentifier("book-edit")

            // As on an author's page: the book looked up again, for a record
            // scanned thin or before the scan knew better. Typed corrections
            // stay with "Modifier"; this one rewrites only what the web says.
            Button("Mettre à jour", systemImage: "arrow.clockwise") {
                onAction(.refresh)
            }
            .accessibilityIdentifier("book-refresh")

            // A volume the scan did not recognise as one is filed from here,
            // without going through the whole edit form. Only for a book in no
            // saga: a filed one changes series from the edit form.
            if book.series == nil {
                Button("Ajouter à une série", systemImage: "square.stack") {
                    onAction(.joinSeries)
                }
                .accessibilityIdentifier("book-join-series")
            }

            // Who pressed the book on the reader, picked from their contacts.
            // Once recorded, it is also corrected from its own section.
            Button("Conseillé par…", systemImage: "person.badge.plus") {
                onAction(.recommend)
            }
            .accessibilityIdentifier("book-recommend")

            // Its French edition watched for and announced the day it is out.
            ForEach(offer.awaitable) { format in
                Button(format.awaitLabel, systemImage: format == .audiobook ? "headphones" : "character.book.closed") {
                    onAction(.awaitEdition(format))
                }
                .accessibilityIdentifier("book-await-\(format.rawValue)")
            }
            ForEach(offer.awaited) { edition in
                Button(
                    edition.format == .audiobook
                        ? String(localized: "Ne plus guetter en audio")
                        : String(localized: "Ne plus guetter en français"),
                    systemImage: "bell.slash"
                ) {
                    onAction(.stopAwaiting(edition))
                }
            }

            // Not on the segmented picker, which holds the states a book moves
            // through: dropping one is an ending, chosen once, from here.
            if book.status == .dropped {
                Button("Reprendre", systemImage: "arrow.uturn.backward") {
                    onAction(.setStatus(.reading))
                }
                .accessibilityIdentifier("book-resume")
            } else {
                Button("Abandonner", systemImage: "hand.thumbsdown") {
                    onAction(.setStatus(.dropped))
                }
                .accessibilityIdentifier("book-drop")
            }

            Button("Supprimer", systemImage: "trash", role: .destructive) {
                confirmDelete = true
            }
            .accessibilityIdentifier("book-delete")
        } label: {
            Image(systemName: "ellipsis")
        }
        .accessibilityLabel(Text("Plus d'actions"))
        .accessibilityIdentifier("book-detail-menu")
        // Attached to the menu: a dialog hung on the sheet's root would anchor
        // to the whole screen instead of the button that asked.
        .confirmationDialog(
            "Supprimer ce livre ?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                onAction(.delete)
            }
            .accessibilityIdentifier("choice-delete")
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Votre note sera perdue. Cette action est définitive.")
        }
    }
}

#Preview {
    NavigationStack {
        Text(verbatim: "Le Nom du vent")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    BookActionsMenu(book: .preview, offer: EditionOffer()) { _ in }
                }
            }
    }
}
