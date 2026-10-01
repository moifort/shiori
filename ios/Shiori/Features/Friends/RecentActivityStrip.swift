import SwiftUI

/// A friend's recent activity as up to five covers scrolled sideways: the
/// book in progress, the last one read, the last one hearted, the last one
/// added and the last one dropped. No title — the cover already shows the book — but
/// under each, what happened, its symbol first, in its colour. A tap on a
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
        VStack(alignment: .leading, spacing: 4) {
            BookCover(book: activity.book.book, width: Self.coverWidth, showsFormatBadge: false)
            // Not a caption label: its fixed icon column would leave
            // "Abandonné" too little of a cover's width.
            HStack(spacing: 3) {
                icon(activity)
                Text(caption(activity))
                    .lineLimit(1)
                    // Cut rather than shrunk: every caption keeps one size.
                    .truncationMode(.tail)
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(tint(activity))
        }
        .frame(width: Self.coverWidth, alignment: .leading)
    }

    /// A check or a plus is a bare stroke beside the filled book, heart and
    /// thumb, so those two sit in a disc of their colour to weigh the same.
    @ViewBuilder
    private func icon(_ activity: RecentActivity) -> some View {
        switch activity {
        case .finished, .added:
            Image(systemName: symbol(activity))
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 13, height: 13)
                .background(tint(activity), in: Circle())
        case .reading, .hearted, .dropped:
            Image(systemName: symbol(activity)).imageScale(.small)
        }
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
        case .dropped: .secondary
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
