import SwiftUI

/// One of the lists the reader's own shelf opens on.
enum MyShelfList: Hashable {
    case favorites, pile, reading
}

/// The top of the Partagé tab: the reader's own shelf as their friends see it,
/// in three boxes — favourites, pile, books in progress — each opening its list.
///
/// Drawn from the very query a friend's profile is drawn from, so a book kept
/// to themselves is absent here too: what the reader looks at is what is
/// shared, not a second opinion of it.
struct MyShelfHeader: View {
    let shelf: FriendProfile
    let open: (MyShelfList) -> Void

    var body: some View {
        VStack(spacing: 10) {
            favoritesBox
            HStack(alignment: .top, spacing: 10) {
                pileBox
                readingBox
            }
        }
    }

    private var favoritesBox: some View {
        let sagas = shelf.favoriteSagas.count
        let books = shelf.favorites.count
        return ShelfBox(
            title: "Mes favoris",
            systemImage: "heart.fill",
            tint: .pink,
            count: sagas + books,
            action: { open(.favorites) }
        ) {
            if sagas + books == 0 {
                emptyLine("Aucun favori pour l'instant.")
            } else {
                Text("\(sagas) série(s) · \(books) livre(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } strip: {
            if sagas + books > 0 {
                covers(shelf.favoriteSagas.map(\.coverBook) + shelf.favorites.map(\.book))
            }
        }
        .accessibilityIdentifier("my-shelf-favorites")
    }

    private var pileBox: some View {
        ShelfBox(
            title: "Ma pile",
            systemImage: ReadingStatus.toRead.symbol,
            tint: ReadingStatus.toRead.tint,
            count: shelf.pile.count,
            action: { open(.pile) }
        ) {
            if let next = shelf.pile.first?.book {
                bookLine(next.title, detail: next.authorLine)
            } else {
                emptyLine("Votre pile est vide.")
            }
        }
        .accessibilityIdentifier("my-shelf-pile")
    }

    private var readingBox: some View {
        ShelfBox(
            title: "En cours",
            systemImage: ReadingStatus.reading.symbol,
            tint: ReadingStatus.reading.tint,
            count: shelf.reading.count,
            action: { open(.reading) }
        ) {
            if let current = shelf.reading.first?.book {
                // A volume of a saga says which saga: "Tome 3" of what, otherwise.
                bookLine(
                    current.title,
                    detail: current.series.map { "\($0.name) · \($0.label)" } ?? current.authorLine
                )
            } else {
                emptyLine("Aucune lecture en cours.")
            }
        }
        .accessibilityIdentifier("my-shelf-reading")
    }

    /// Every favourite's cover, sagas first, running to the box's edges and
    /// scrolling sideways past them: the row is the favourites at a glance,
    /// not a sample of six. A tap on a cover still opens the list.
    private func covers(_ books: [Book]) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 8) {
                ForEach(books) { book in
                    BookCover(book: book, width: 48, showsFormatBadge: false)
                }
            }
        }
        .onTapGesture { open(.favorites) }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, ShelfBoxMetrics.padding, for: .scrollContent)
        .padding(.horizontal, -ShelfBoxMetrics.padding)
        .accessibilityHidden(true)
    }

    private func bookLine(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.medium))
                .lineLimit(2)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func emptyLine(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

/// A rounded box with a tinted heading, a count, and a line or two of what it
/// holds, all of it the tap target; under it an optional strip that scrolls
/// sideways, kept outside the button so a drag scrolls it rather than opening
/// the list.
private struct ShelfBox<Content: View, Strip: View>: View {
    let title: LocalizedStringKey
    let systemImage: String
    let tint: Color
    let count: Int
    let action: () -> Void
    @ViewBuilder let content: Content
    @ViewBuilder let strip: Strip

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: action) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: systemImage)
                            .foregroundStyle(tint)
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                        Spacer(minLength: 4)
                        Text(verbatim: "\(count)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    content
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            strip
        }
        .padding(ShelfBoxMetrics.padding)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
    }
}

extension ShelfBox where Strip == EmptyView {
    init(
        title: LocalizedStringKey,
        systemImage: String,
        tint: Color,
        count: Int,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title: title,
            systemImage: systemImage,
            tint: tint,
            count: count,
            action: action,
            content: content,
            strip: { EmptyView() }
        )
    }
}

/// Between a box's edge and its content; the favourites' cover strip reaches
/// back across it to run edge to edge.
private enum ShelfBoxMetrics {
    static let padding: CGFloat = 14
}
