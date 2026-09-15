import SwiftUI

/// A cover with two short lines under it, for the horizontal shelves.
struct CoverTile: View {
    let book: Book
    let caption: String
    var width: CGFloat = 84

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            BookCover(book: book, width: width)
            Text(book.title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: width, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(book.title), \(caption)")
    }
}

#Preview {
    CoverTile(
        book: Book(id: "1", title: "Le Nom du vent", authors: ["Patrick Rothfuss"], status: .reading),
        caption: "depuis 12 j"
    )
    .padding()
}
