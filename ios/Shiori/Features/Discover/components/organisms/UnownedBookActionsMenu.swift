import SwiftUI

/// The "…" in the corner of a book nobody here holds, as on a book of the
/// library: what the page does not draw. A cover picked here is the book's
/// for every reader.
struct UnownedBookActionsMenu<Extra: View>: View {
    let onChooseCover: () -> Void
    /// What a page adds over the cover: a discovery's eye, when "Guetter"
    /// took its place in the hero.
    @ViewBuilder var extra: () -> Extra

    var body: some View {
        Menu {
            extra()
            Button("Couverture", systemImage: "photo", action: onChooseCover)
                .accessibilityIdentifier("unowned-cover")
        } label: {
            Image(systemName: "ellipsis")
        }
        .accessibilityLabel(Text("Plus d'actions"))
        .accessibilityIdentifier("unowned-menu")
    }
}

extension UnownedBookActionsMenu where Extra == EmptyView {
    init(onChooseCover: @escaping () -> Void) {
        self.init(onChooseCover: onChooseCover) { EmptyView() }
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
