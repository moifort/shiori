import SwiftUI

/// Everything the "…" menu of an author can ask for.
enum AuthorMenuAction {
    case edit
    case portrait
}

/// The "…" in an author's corner, for an author the reader holds books of:
/// correcting what the AI wrote, as a book's menu does.
struct AuthorActionsMenu: View {
    let onAction: (AuthorMenuAction) -> Void

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
                    AuthorActionsMenu { _ in }
                }
            }
    }
}
