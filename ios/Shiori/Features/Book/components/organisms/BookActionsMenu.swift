import SwiftUI

/// Everything the "…" menu of a book can ask for.
enum BookMenuAction {
    case edit
    /// Another cover picked, among those the record holds and the sources find.
    case chooseCover
    case joinSeries
    case recommend
    case awaitEdition(ReleaseFormat)
    case stopAwaiting(AwaitedEdition)
    case setStatus(ReadingStatus)
    /// Keeps the book out of every shared library, or lets it back in.
    case toggleHidden
    case delete
}

/// The "…" in a book's corner. The page's hero takes the book to its next
/// state and the series opens from its row: the menu holds the full choice of
/// status, sharing, and what the page does not draw.
struct BookActionsMenu: View {
    let book: Book
    /// What may be awaited of it in the app's language, and what is.
    let offer: EditionOffer
    let onAction: (BookMenuAction) -> Void

    @State private var confirmDelete = false

    var body: some View {
        Menu {
            // Every state a book moves through, the one it is in ticked: the
            // hero's button only ever offers the next one.
            Picker(selection: Binding(get: { book.status }, set: { onAction(.setStatus($0)) })) {
                // Names only: the tick marks the one chosen, and the symbol of
                // "Lu" is a tick of its own.
                ForEach(ReadingStatus.progression) { status in
                    Text(status.label).tag(status)
                }
            } label: {
                Label("Statut", systemImage: book.status.symbol)
                Text(book.status.label)
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("book-status")

            Button("Modifier", systemImage: "pencil") {
                onAction(.edit)
            }
            .accessibilityIdentifier("book-edit")

            // What a reader most often wanted from looking a record up again:
            // a better cover. Picked among those found, free, with no AI.
            Button("Changer la couverture", systemImage: "photo") {
                onAction(.chooseCover)
            }
            .accessibilityIdentifier("book-cover")

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

            // Kept out of every library a friend sees, the counts included.
            Toggle(isOn: Binding(get: { book.hidden }, set: { _ in onAction(.toggleHidden) })) {
                Label("Ne pas partager", systemImage: "eye.slash")
            }
            .accessibilityIdentifier("book-hidden")

            // Not with the states a book moves through: dropping one is an
            // ending, chosen once, from here.
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
