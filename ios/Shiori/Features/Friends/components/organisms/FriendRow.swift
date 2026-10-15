import SwiftUI

/// A friend as the Partagé list draws them: the name, their shelf in figures
/// in the top corner as a book row carries its marks, and under the name what
/// moved lately on their shelf, as their page draws it. The invitation sheets draw the same row, so what is being shared
/// reads the way it will be seen.
struct FriendRow: View {
    let friend: Friend
    /// Opens a recent cover's book; without it the covers are part of the
    /// row, and a tap anywhere opens the friend's page.
    var onOpen: ((FriendBook) -> Void)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Grown with the initials it holds, which otherwise spilled out of it.
    @ScaledMetric(relativeTo: .subheadline) private var avatarSide: CGFloat = 40

    /// The figures beside the name, or under it at the accessibility sizes,
    /// where the two on one line left the name two letters long.
    private var nameAndFigures: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Text(friend.initials)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)
                    .frame(width: avatarSide, height: avatarSide)
                    .background(.tint.opacity(0.15), in: .circle)
                nameAndFigures {
                    Text(friend.displayName)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                    HStack(spacing: 10) {
                        Label("\(friend.favoriteCount)", systemImage: "heart")
                            .accessibilityLabel(Text("\(friend.favoriteCount) favoris"))
                        Label("\(friend.readingCount)", systemImage: "book")
                            .accessibilityLabel(Text("\(friend.readingCount) en cours"))
                        Label("\(friend.bookCount)", systemImage: "books.vertical")
                            .accessibilityLabel(Text("\(friend.bookCount) livres partagés"))
                    }
                    .labelStyle(.caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize()
                }
            }
            // The whole width of the row, under the avatar too: the column
            // beside it leaves room for two covers at most.
            let recent = friend.recentActivity.filter { $0.isRecent() }
            if !recent.isEmpty {
                // Out to the card's edges, so a cover slides off it rather
                // than vanish at the row's margin.
                RecentActivityStrip(activities: recent, inset: 16, onOpen: onOpen)
                    .padding(.horizontal, -16)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview("Friend rows") {
    List(Friend.previews) { friend in
        FriendRow(friend: friend)
    }
}
