import SwiftUI

/// One book in the library's mosaic: its cover across the column, the reading
/// status pinned on its corner as the Series and Authors shelves pin it, the
/// headphones on the opposite corner; the title under it and, beneath, the
/// marks a row carries with the reader's judgement. The rest is a tap away.
struct BookTile: View {
    let book: Book
    let width: CGFloat
    /// Off where a filter already says which status every book has.
    var showsStatus = true
    var isAwaited = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            BookCover(book: book, width: width, showsFormatBadge: false)
                .overlay(alignment: .topTrailing) {
                    if showsStatus {
                        ReadingStatusBadge(status: book.status)
                            .offset(x: 5, y: -5)
                    }
                }
                .overlay(alignment: .topLeading) {
                    if book.format == .audiobook {
                        AudiobookBadge(size: 18)
                            .offset(x: -5, y: -5)
                    }
                }
            MosaicCaption(title: book.title) {
                HStack(spacing: 4) {
                    if book.hidden {
                        Image(systemName: "eye.slash")
                            .accessibilityLabel(Text("Non partagé"))
                    }
                    if isAwaited {
                        AwaitedMark()
                    }
                    OpinionMark(
                        rating: book.shownRating,
                        isFavorite: book.favorite,
                        ratingIsInherited: book.ratingIsInherited
                    )
                }
            }
        }
        .frame(width: width, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let saga = SeriesMembership(id: "s1", name: "Chronique du tueur de roi", volume: 2, kind: .main)
    HStack(alignment: .top, spacing: 12) {
        BookTile(
            book: Book(id: "1", title: "La Peur du sage", authors: ["Patrick Rothfuss"], series: saga, status: .reading, rating: 5),
            width: 110
        )
        BookTile(
            book: Book(id: "2", title: "Piranesi", authors: ["Susanna Clarke"], status: .toRead, hidden: true),
            width: 110
        )
    }
    .padding()
}
