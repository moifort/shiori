import SwiftUI

/// The "…" in the corner of a book nobody here holds, as on a book of the
/// library: what the page does not draw. A cover picked here is the book's
/// for every reader.
struct UnownedBookActionsMenu: View {
    let onChooseCover: () -> Void

    var body: some View {
        Menu {
            Button("Couverture", systemImage: "photo", action: onChooseCover)
                .accessibilityIdentifier("unowned-cover")
        } label: {
            Image(systemName: "ellipsis")
        }
        .accessibilityLabel(Text("Plus d'actions"))
        .accessibilityIdentifier("unowned-menu")
    }
}

#Preview {
    NavigationStack {
        Color.clear
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    UnownedBookActionsMenu {}
                }
            }
    }
}
