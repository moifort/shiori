import SwiftUI

/// One book the friends love, as the strip and Découvrir's "Coups de cœur"
/// page draw it: the friend under the cover, the flame in its corner.
struct LovedBookTile: View {
    let loved: LovedBook
    var width: CGFloat = 84
    let onTapped: () -> Void

    var body: some View {
        Button(action: onTapped) {
            CoverTile(book: loved.book.book, caption: loved.lovers.caption, width: width)
                .overlay(alignment: .topLeading) {
                    if loved.lovers.lovedByMany {
                        LovedByManyBadge().offset(x: -6, y: -6)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("discover-friend-book")
    }
}

#Preview {
    LovedBookTile(loved: FriendPicks.preview.books[0]) {}
        .padding()
}
