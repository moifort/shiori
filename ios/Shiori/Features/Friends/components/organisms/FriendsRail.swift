import SwiftUI

/// One rail of the Amis tab: covers as the Library tab draws them, each with
/// its line, and in the corner whose book it is when the page shows more than
/// one friend.
struct FriendsRail: View {
    struct Item: Identifiable {
        let id: String
        let book: Book
        let label: PosterLabel
        /// Nil when the page shows one friend: the corner stays bare.
        let friendName: String?
        let friendAvatar: AccountAvatar
    }

    let title: LocalizedStringKey
    let items: [Item]
    let onOpen: (Item) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RowHeader(title: title, style: .inline)
                .padding(.horizontal, 20)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 13) {
                    ForEach(items) { item in
                        Button { onOpen(item) } label: {
                            PosterCover(book: item.book, label: item.label)
                                .overlay(alignment: .topLeading) {
                                    if let name = item.friendName {
                                        FriendCoverTag(name: name, avatar: item.friendAvatar)
                                            .padding(6)
                                    }
                                }
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(
                            [item.book.title, item.label.caption, item.friendName].compactMap { $0 }
                                .filter { !$0.isEmpty }.joined(separator: ", ")
                        ))
                        .accessibilityAddTraits(.isButton)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollClipDisabled()
            .contentMargins(.horizontal, 20, for: .scrollContent)
        }
    }
}

#Preview {
    FriendsRail(
        title: "Lecture en cours",
        items: FriendsShelf.preview.reading.map {
            .init(
                id: $0.id, book: $0.book.book, label: PosterLabel.of($0.book.book, in: .recent),
                friendName: $0.friendName, friendAvatar: $0.book.ownerAvatar
            )
        },
        onOpen: { _ in }
    )
    .preferredColorScheme(.dark)
}
