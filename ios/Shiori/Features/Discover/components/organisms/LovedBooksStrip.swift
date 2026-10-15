import SwiftUI

/// The Books shelf's strip: the covers, the friend under each — no title, the
/// cover says it.
struct LovedBooksStrip: View {
    let books: [LovedBook]
    let onTapped: (LovedBook) -> Void

    var body: some View {
        PicksStrip {
            ForEach(books) { loved in
                LovedBookTile(loved: loved) { onTapped(loved) }
            }
        }
    }
}

#Preview {
    List {
        LovedBooksStrip(books: FriendPicks.preview.books) { _ in }
    }
}
