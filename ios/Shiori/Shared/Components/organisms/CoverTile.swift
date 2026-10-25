import SwiftUI

/// A cover with one short line under it, for the horizontal shelves: the cover
/// already shows the title, so the line says what matters about the book here.
struct CoverTile: View {
    let book: Book
    let caption: String
    var width: CGFloat = 84
    /// Nil for the secondary grey.
    var captionTint: Color?
    /// Where a caption too long for the cover gives way: its middle keeps
    /// both ends, as a prize keeps its year.
    var captionTruncation: Text.TruncationMode = .tail

    /// The headphones pill, a touch above a library row's rather than grown
    /// with the shelf's larger cover.
    static let formatBadgeSize: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            BookCover(book: book, width: width, formatBadgeSize: Self.formatBadgeSize)
            // No caption at all where a shelf shows bare covers.
            if !caption.isEmpty {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(captionTint.map(AnyShapeStyle.init) ?? AnyShapeStyle(.secondary))
                    .lineLimit(1)
                    // A little smaller before it gives way: "Goncourt 2025"
                    // fits whole under a summary cover.
                    .minimumScaleFactor(0.8)
                    .truncationMode(captionTruncation)
            }
        }
        .frame(width: width, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caption.isEmpty ? book.title : "\(book.title), \(caption)")
    }
}

#Preview {
    CoverTile(
        book: Book(id: "1", title: "Le Nom du vent", authors: ["Patrick Rothfuss"], status: .reading),
        caption: "depuis 12j"
    )
    .padding()
}
