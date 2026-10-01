import SwiftUI

/// A friend's recent activity as four covers across the card: the book in
/// progress, the last one finished, the last one dropped, the last one
/// hearted. No title and no caption — the cover already shows the book — but
/// in its corner, where it stands: its status, and a heart on a favourite.
/// A tap opens the book.
struct RecentActivityStrip: View {
    let activities: [RecentActivity]
    let onOpen: (FriendBook) -> Void

    /// One slot per kind of activity, so a cover keeps its size whether one
    /// or four moved lately.
    private static let slots = 4

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(activities.prefix(Self.slots)) { activity in
                Button { onOpen(activity.book) } label: {
                    cover(activity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityLabel(activity))
                .accessibilityIdentifier("recent-activity-cover")
            }
            ForEach(activities.count..<max(activities.count, Self.slots), id: \.self) { _ in
                Color.clear.aspectRatio(2 / 3, contentMode: .fit)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .listRowInsets(EdgeInsets())
    }

    private func cover(_ activity: RecentActivity) -> some View {
        let book = activity.book.book
        return Color.clear
            .aspectRatio(2 / 3, contentMode: .fit)
            .overlay {
                GeometryReader { proxy in
                    BookCover(book: book, width: proxy.size.width, showsFormatBadge: false)
                }
            }
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 3) {
                    ReadingStatusBadge(status: book.status)
                    if book.favorite {
                        CoverBadge(systemImage: "heart.fill", tint: .red)
                    }
                }
                .padding(5)
            }
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
        case .dropped: String(localized: "Abandonné")
        case .hearted: String(localized: "Coup de cœur")
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
