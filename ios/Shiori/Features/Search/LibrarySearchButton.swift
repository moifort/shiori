import SwiftUI

extension View {
    /// The bar of a pushed shelf, the home's: its name on the left and the
    /// magnifier on the right, leaving as the reader scrolls down. The TV app
    /// keeps its search a tap away on every page; the magnifier opens the
    /// library's search sheet.
    func searchesLibrary(_ title: String) -> some View {
        modifier(LibrarySearchButton(title: title))
    }
}

private struct LibrarySearchButton: ViewModifier {
    let title: String
    @State private var showsSearch = false

    func body(content: Content) -> some View {
        content
            .scrollAwayBar(title) { showsSearch = true }
            .sheet(isPresented: $showsSearch) { LibrarySearchScreen() }
    }
}
