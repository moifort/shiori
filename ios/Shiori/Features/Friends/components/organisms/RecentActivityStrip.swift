import SwiftUI

/// A friend's recent activity as up to five covers scrolled sideways: the
/// book in progress, the last one read, the last one hearted, the last one
/// added and the last one dropped. Each is drawn as the home shelves draw a
/// cover — no title, the cover already shows the book, but under it, in
/// the same grey, what happened: how far a recording got, else "En cours",
/// "Lu", "Favori", "Ajouté" or "Abandonné". A tap on a cover opens its book;
/// on the friends list, the rest of the row opens the friend's page.
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
    /// What the headphones overhang a tile's cover by, as on the home shelves.
    private static let badgeRoom = (CoverTile.formatBadgeSize / 3).rounded(.up)

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(activities.prefix(Self.slots)) { activity in
                    if let onOpen {
                        Button { onOpen(activity.book) } label: {
                            tile(activity)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("recent-activity-cover")
                    } else {
                        tile(activity)
                    }
                }
            }
            .padding(.horizontal, inset)
            // Room for the headphones, which overhang a recording's corner and
            // the scroll view would otherwise clip; taken back outside so the
            // covers stay where they were.
            .padding(.top, Self.badgeRoom)
        }
        .padding(.top, -Self.badgeRoom)
    }

    /// The home shelves' tile, with what happened right under the cover.
    private func tile(_ activity: RecentActivity) -> some View {
        CoverTile(book: activity.book.book, caption: caption(activity), width: Self.coverWidth)
    }

    /// What happened, worded as the home's "En cours" shelf words it: a
    /// recording in progress says how far the player got, anything else the
    /// name of the move.
    private func caption(_ activity: RecentActivity) -> String {
        switch activity {
        case .reading:
            if let progress = activity.book.book.listeningProgressLabel {
                return String(localized: "\(progress) écouté")
            }
            return String(localized: "En cours")
        case .finished: return String(localized: "Lu")
        case .hearted: return String(localized: "Favori")
        case .added: return String(localized: "Ajouté")
        case .dropped: return String(localized: "Abandonné")
        }
    }
}

#Preview {
    List {
        RecentActivityStrip(activities: Friend.previews[0].recentActivity, inset: 16) { _ in }
            .padding(.horizontal, -16)
    }
}
