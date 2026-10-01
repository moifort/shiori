import SwiftUI

/// A cover with two short lines under it, for the horizontal shelves — or the
/// caption alone, where the cover says enough.
struct CoverTile: View {
    let book: Book
    let caption: String
    var width: CGFloat = 84
    var showsTitle = true
    /// Nil for the secondary grey.
    var captionTint: Color?

    /// The headphones pill, a touch above a library row's rather than grown
    /// with the shelf's larger cover.
    static let formatBadgeSize: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            BookCover(book: book, width: width, formatBadgeSize: Self.formatBadgeSize)
            if showsTitle {
                Text(book.title)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
            }
            Text(caption)
                .font(.caption2)
                .foregroundStyle(captionTint.map(AnyShapeStyle.init) ?? AnyShapeStyle(.secondary))
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
