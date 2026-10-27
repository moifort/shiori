import SwiftUI

/// Everything the "…" menu of an author or a narrator can ask for.
enum PersonMenuAction {
    case edit
    case portrait
}

/// The "…" in an author's or a narrator's corner, for one the reader holds
/// books of: correcting what the AI wrote, as a book's menu does.
struct PersonActionsMenu: View {
    let onAction: (PersonMenuAction) -> Void

    var body: some View {
        Menu {
            Button("Modifier", systemImage: "pencil") {
                onAction(.edit)
            }
            .accessibilityIdentifier("author-edit")
            Button("Portrait", systemImage: "person.crop.circle") {
                onAction(.portrait)
            }
            .accessibilityIdentifier("author-portrait")
        } label: {
            Image(systemName: "ellipsis")
        }
        .accessibilityLabel(Text("Plus d'actions"))
        .accessibilityIdentifier("author-menu")
    }
}

#Preview {
    NavigationStack {
        Text(verbatim: "Robin Hobb")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    PersonActionsMenu { _ in }
                }
            }
    }
}
