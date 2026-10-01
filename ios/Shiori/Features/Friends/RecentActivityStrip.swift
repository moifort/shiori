import SwiftUI

/// A friend's recent activity as large covers side by side: the book in
/// progress, the last one finished, the last one hearted. No title — the cover
/// already shows it — but under each, where the book stands as icons (its
/// status, and a heart when it is a favourite) and what happened, in its
/// colour. A tap opens the book.
struct RecentActivityStrip: View {
    let activities: [RecentActivity]
    let onOpen: (FriendBook) -> Void

    /// Three covers across the card of the narrowest phone.
    private static let coverWidth: CGFloat = 100

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(activities) { activity in
                    Button { onOpen(activity.book) } label: {
                        tile(activity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("recent-activity-cover")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .listRowInsets(EdgeInsets())
    }

    private func tile(_ activity: RecentActivity) -> some View {
        let book = activity.book.book
        return VStack(alignment: .leading, spacing: 5) {
            BookCover(book: book, width: Self.coverWidth, formatBadgeSize: CoverTile.formatBadgeSize)
            HStack(spacing: 4) {
                Image(systemName: book.status.symbol)
                    .foregroundStyle(book.status.tint)
                // The caption already says a heart was given.
                if book.favorite, !activity.isHeart {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                }
                Text(caption(activity))
                    .foregroundStyle(tint(activity))
                    .lineLimit(1)
            }
            .font(.caption2.weight(.medium))
        }
        .frame(width: Self.coverWidth, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(activity))
    }

    private func accessibilityLabel(_ activity: RecentActivity) -> String {
        let book = activity.book.book
        let favorite = book.favorite ? [String(localized: "Favori")] : []
        return ([book.title, caption(activity), book.status.label] + favorite).joined(separator: ", ")
    }

    private func caption(_ activity: RecentActivity) -> String {
        switch activity {
        case .reading: String(localized: "En cours")
        case .finished: String(localized: "Terminé")
        case .hearted: String(localized: "Coup de cœur")
        }
    }

    private func tint(_ activity: RecentActivity) -> Color {
        switch activity {
        case .reading: ReadingStatus.reading.tint
        case .finished: ReadingStatus.read.tint
        case .hearted: .red
        }
    }
}

/// A friend's books as a strip of bare covers — no title, no badge — every
/// one of them, scrolled sideways. A tap opens the book.
struct FriendCoverStrip: View {
    let books: [FriendBook]
    let onOpen: (FriendBook) -> Void

    private static let coverWidth: CGFloat = 76

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 10) {
                ForEach(books) { entry in
                    Button { onOpen(entry) } label: {
                        BookCover(book: entry.book, width: Self.coverWidth, showsFormatBadge: false)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(entry.book.title)
                    .accessibilityIdentifier("friend-book-cover")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .listRowInsets(EdgeInsets())
    }
}

private extension RecentActivity {
    var isHeart: Bool {
        if case .hearted = self { true } else { false }
    }
}
