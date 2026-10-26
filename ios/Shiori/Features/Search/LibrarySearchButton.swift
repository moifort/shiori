import SwiftUI

extension View {
    /// The magnifier in the bar of a pushed shelf, as the TV app keeps its
    /// search a tap away on every page: it opens the library's search sheet.
    func searchesLibrary() -> some View {
        modifier(LibrarySearchButton())
    }
}

private struct LibrarySearchButton: ViewModifier {
    @State private var showsSearch = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    ToolbarIconButton(title: "Rechercher", systemImage: "magnifyingglass") {
                        showsSearch = true
                    }
                    .accessibilityIdentifier("library-search")
                }
            }
            .sheet(isPresented: $showsSearch) { LibrarySearchScreen() }
    }
}
