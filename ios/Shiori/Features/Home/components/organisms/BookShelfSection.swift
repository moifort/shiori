import SwiftUI

/// A horizontal row of covers. The row runs off the trailing edge of the card on
/// purpose: a cropped cover is what tells a reader the row scrolls. An empty
/// shelf says what would fill it.
struct BookShelfSection: View {
    let title: LocalizedStringKey
    let books: [Book]
    let caption: (Book) -> String
    let emptyMessage: LocalizedStringKey
    var onHeaderTapped: (() -> Void)?
    let onBookTapped: (Book) -> Void

    var body: some View {
        WidgetCard(title: title, action: onHeaderTapped) {
            if books.isEmpty {
                WidgetEmptyMessage(text: emptyMessage, placeholder: .covers)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(books) { book in
                            Button { onBookTapped(book) } label: {
                                CoverTile(book: book, caption: caption(book))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.horizontal, -16)
            }
        }
    }
}

#Preview {
    BookShelfSection(
        title: "En cours",
        books: [
            Book(id: "1", title: "La Peur du sage", authors: ["Patrick Rothfuss"], status: .reading),
            Book(id: "2", title: "Dune", authors: ["Frank Herbert"], status: .reading),
            Book(id: "3", title: "One Piece", authors: ["Eiichirō Oda"], status: .reading),
            Book(id: "4", title: "Blacksad", authors: ["Juan Díaz Canales"], status: .reading),
        ],
        caption: { $0.authorLine },
        emptyMessage: "Aucun livre en cours de lecture.",
        onHeaderTapped: {},
        onBookTapped: { _ in }
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Empty") {
    BookShelfSection(
        title: "En cours",
        books: [],
        caption: { $0.authorLine },
        emptyMessage: "Aucun livre en cours de lecture.",
        onHeaderTapped: {},
        onBookTapped: { _ in }
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
