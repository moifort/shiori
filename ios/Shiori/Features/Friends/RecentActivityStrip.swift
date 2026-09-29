import SwiftUI

/// A friend's recent activity as large covers side by side: the book in
/// progress, the last one finished, the last one hearted, each captioned with
/// what happened in its colour. A tap opens the book.
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
                        CoverTile(
                            book: activity.book.book,
                            caption: caption(activity),
                            width: Self.coverWidth,
                            captionTint: tint(activity)
                        )
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
