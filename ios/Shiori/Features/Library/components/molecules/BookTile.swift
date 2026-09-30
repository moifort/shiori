import SwiftUI

/// One book in the library's mosaic, as the Photos app draws a photo: the
/// cover alone, square-cornered, edge to edge with its neighbours. Over its
/// foot, the heart of a favourite on the left and the reading status on the
/// right, where Photos puts a favourite's heart and a video's length. Whether
/// it is a recording goes unsaid: one more glyph was noise. The rest is a tap
/// away.
struct BookTile: View {
    let book: Book
    let width: CGFloat
    /// Off where a filter already says which status every book has.
    var showsStatus = true

    var body: some View {
        BookCover(book: book, width: width, showsFormatBadge: false, cornerRadius: 0)
            .overlay(alignment: .bottom) {
                if book.favorite || showsStatus {
                    MosaicGlyphs {
                        if book.favorite { Image(systemName: "heart.fill") }
                    } trailing: {
                        if showsStatus {
                            Image(systemName: book.status.symbol)
                                .accessibilityLabel(Text(book.status.shelfTitle))
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(book.title))
    }
}

#Preview {
    HStack(spacing: 2) {
        BookTile(
            book: Book(id: "1", title: "La Peur du sage", authors: ["Patrick Rothfuss"], format: .audiobook, status: .reading, favorite: true),
            width: 97
        )
        BookTile(
            book: Book(id: "2", title: "Piranesi", authors: ["Susanna Clarke"], status: .toRead),
            width: 97
        )
    }
}
