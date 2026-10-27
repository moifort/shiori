import SwiftUI

/// The shelves that close the entry screen, grouped as Settings rows: every
/// book, and those given up on when there are some.
struct ShelfLinkRows: View {
    var showsDropped: Bool
    let onOpen: (BookShelf) -> Void

    var body: some View {
        LinkRowGroup {
            LinkRow(symbol: "square.grid.3x3", title: BookShelf.all.title) { onOpen(.all) }
            if showsDropped {
                Divider().padding(.leading, 54)
                LinkRow(symbol: "hand.thumbsdown", title: BookShelf.dropped.title) { onOpen(.dropped) }
            }
        }
    }
}

#Preview {
    ShelfLinkRows(showsDropped: true) { _ in }
        .padding(.vertical)
        .background(.black)
        .environment(\.colorScheme, .dark)
}
