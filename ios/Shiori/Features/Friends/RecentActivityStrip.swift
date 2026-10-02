import SwiftUI

/// A friend's recent activity as up to five covers scrolled sideways: the
/// book in progress, the last one read, the last one hearted, the last one
/// added and the last one dropped. No title — the cover already shows the book — and
/// no caption: what happened is its symbol, centred on the cover, in its colour. A tap on a
/// cover opens its book; on the friends list, the rest of the row opens the
/// friend's page.
struct RecentActivityStrip: View {
    let activities: [RecentActivity]
    /// Where the first cover starts, inside the scroll, so the covers slide
    /// out to the card's edge rather than vanish at its margin.
    var inset: CGFloat = 0
    var onOpen: ((FriendBook) -> Void)?

    /// One kind of activity each, so never more than five.
    private static let slots = 5

    /// Wider than five covers sharing the card would be: the last one peeks
    /// out, and the strip scrolls to it.
    private static let coverWidth: CGFloat = 72
    /// Taller than a cover's own proportions: with no caption under it, the
    /// cover takes the room the caption had, and some.
    private static let coverHeight: CGFloat = 130

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 8) {
                ForEach(activities.prefix(Self.slots)) { activity in
                    if let onOpen {
                        Button { onOpen(activity.book) } label: {
                            tile(activity)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(accessibilityLabel(activity))
                        .accessibilityIdentifier("recent-activity-cover")
                    } else {
                        tile(activity)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(accessibilityLabel(activity))
                    }
                }
            }
            .padding(.horizontal, inset)
        }
    }

    private func accessibilityLabel(_ activity: RecentActivity) -> String {
        "\(activity.book.book.title), \(caption(activity))"
    }

    private func tile(_ activity: RecentActivity) -> some View {
        BookCover(
            book: activity.book.book,
            width: Self.coverWidth,
            showsFormatBadge: false,
            minHeight: Self.coverHeight
        )
        .overlay { icon(activity) }
    }

    /// What happened, as a solid disc of its colour in the middle of the
    /// cover: opaque, so the symbol reads whatever the photo under it.
    private func icon(_ activity: RecentActivity) -> some View {
        Image(systemName: symbol(activity))
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(tint(activity), in: Circle())
            .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
    }

    private func caption(_ activity: RecentActivity) -> String {
        switch activity {
        case .reading: String(localized: "En cours")
        case .finished: String(localized: "Lu")
        case .hearted: String(localized: "Favori")
        case .added: String(localized: "Ajouté")
        case .dropped: String(localized: "Abandonné")
        }
    }

    /// The status symbols the rest of the app draws, and a plus for a book
    /// just shelved, whatever its status.
    private func symbol(_ activity: RecentActivity) -> String {
        switch activity {
        case .reading: ReadingStatus.reading.symbol
        case .finished: ReadingStatus.read.symbol
        case .hearted: "heart.fill"
        case .added: "plus"
        case .dropped: ReadingStatus.dropped.symbol
        }
    }

    private func tint(_ activity: RecentActivity) -> Color {
        switch activity {
        case .reading: ReadingStatus.reading.tint
        case .finished: ReadingStatus.read.tint
        case .hearted: .red
        case .added: ReadingStatus.toRead.tint
        // Not .secondary: translucent, the disc would let the cover through.
        case .dropped: Color(.systemGray)
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
