import SwiftUI

/// Everything the "…" menu of a saga can ask for.
enum SeriesMenuAction {
    case edit
    case declareVolumeCount
    case merge
    case delete
}

/// The "…" in a saga's corner, for a saga the reader holds volumes of. Only
/// what the page does not draw: following is the bell's, beside the stars.
struct SeriesActionsMenu: View {
    /// The catalogue is drawn from the reader's own count.
    let isProvisional: Bool
    /// How many of its books the removal takes with it.
    let ownedCount: Int
    let onAction: (SeriesMenuAction) -> Void

    @State private var confirmDelete = false

    var body: some View {
        Menu {
            Button("Modifier", systemImage: "pencil") {
                onAction(.edit)
            }
            .accessibilityIdentifier("series-edit")
            // The count is the reader's own: they can correct it for as long
            // as it is what the screen is drawn from.
            if isProvisional {
                Button("Nombre de tomes", systemImage: "number") {
                    onAction(.declareVolumeCount)
                }
                .accessibilityIdentifier("series-volume-count")
            }
            // A scan and an import often name one saga twice: the reader keeps
            // one, and this one's volumes move there.
            Button("Fusionner avec…", systemImage: "arrow.triangle.merge") {
                onAction(.merge)
            }
            .accessibilityIdentifier("series-merge")
            Divider()
            Button("Supprimer", systemImage: "trash", role: .destructive) {
                confirmDelete = true
            }
            .accessibilityIdentifier("series-delete")
        } label: {
            Image(systemName: "ellipsis")
        }
        .accessibilityLabel(Text("Plus d'actions"))
        .accessibilityIdentifier("series-menu")
        // Attached to the menu, as on the book sheet: the dialog rises from the
        // button that asked rather than the screen.
        .confirmationDialog(
            "Supprimer la série ?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) { onAction(.delete) }
                .accessibilityIdentifier("choice-delete-series")
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Les \(ownedCount) livres de cette série dans votre bibliothèque seront supprimés avec elle, ainsi que votre note. Cette action est définitive.")
        }
    }
}

#Preview {
    NavigationStack {
        Text(verbatim: "L'Assassin royal")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    SeriesActionsMenu(
                        isProvisional: false, ownedCount: 6
                    ) { _ in }
                }
            }
    }
}
