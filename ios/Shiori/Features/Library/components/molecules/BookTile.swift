import SwiftUI

/// One book in the library's mosaic, as the Photos app draws a photo: the
/// cover alone, square-cornered, edge to edge with its neighbours, with the
/// reading status in its middle. Over its foot, the heart of a favourite on
/// the left and the headphones of a recording on the right, where Photos puts
/// a favourite's heart and a video's length. The rest is a tap away.
struct BookTile: View {
    let book: Book
    let width: CGFloat

    var body: some View {
        BookCover(book: book, width: width, showsFormatBadge: false, cornerRadius: 0)
            .overlay {
                MosaicStatusBadge(symbol: book.status.symbol, label: book.status.shelfTitle)
            }
            .overlay(alignment: .bottom) {
                if book.favorite || book.format == .audiobook {
                    MosaicGlyphs {
                        if book.favorite { Image(systemName: "heart.fill") }
                    } trailing: {
                        if book.format == .audiobook { Image(systemName: "headphones") }
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
