import SwiftUI

/// Everything the "…" menu of a saga can ask for.
enum SeriesMenuAction {
    case refresh
    case declareVolumeCount
    case setFollowed(Bool)
    case merge
    case delete
}

/// The "…" in a saga's corner, for a saga the reader holds volumes of.
struct SeriesActionsMenu: View {
    /// A catalogue is on screen: only then can it be looked up again.
    let hasCatalogue: Bool
    /// The catalogue is drawn from the reader's own count.
    let isProvisional: Bool
    let isFollowed: Bool
    /// How many of its books the removal takes with it.
    let ownedCount: Int
    let onAction: (SeriesMenuAction) -> Void

    @State private var confirmDelete = false

    var body: some View {
        Menu {
            // Only over a catalogue: with none, the screen's own retry button
            // already asks the world about the saga.
            if hasCatalogue {
                Button("Mettre à jour", systemImage: "arrow.clockwise") {
                    onAction(.refresh)
                }
                .accessibilityIdentifier("series-refresh")
            }
            // The count is the reader's own: they can correct it for as long
            // as it is what the screen is drawn from.
            if isProvisional {
                Button("Nombre de tomes", systemImage: "number") {
                    onAction(.declareVolumeCount)
                }
                .accessibilityIdentifier("series-volume-count")
            }
            // Only the saga is set aside: its volumes keep their own statuses.
            if isFollowed {
                Button("Ne plus suivre", systemImage: "bell.slash") {
                    onAction(.setFollowed(false))
                }
                .accessibilityIdentifier("series-unfollow")
            } else {
                Button("Suivre", systemImage: "bell") {
                    onAction(.setFollowed(true))
                }
                .accessibilityIdentifier("series-follow")
            }
            // A scan and an import often name one saga twice: the reader keeps
            // one, and this one's volumes move there.
            Button("Fusionner avec…", systemImage: "arrow.triangle.merge") {
                onAction(.merge)
            }
            .accessibilityIdentifier("series-merge")
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
                        hasCatalogue: true, isProvisional: false, isFollowed: true, ownedCount: 6
                    ) { _ in }
                }
            }
    }
}
