import SwiftUI

/// Everything the Amis tab can ask for.
enum FriendsAction {
    case toggle(String)
    case openBook(FriendsShelfEntry)
    case openMyBook(FriendBook)
    case openLibrary(Friend)
    case openSeries(Friend)
    case invite
    case refresh
}

/// The Amis tab, as the Library tab lays itself out: the friends' avatars at
/// the top, which narrow the whole page — nobody picked shows every friend,
/// each one tapped narrows it to the friends picked — then, for one friend,
/// the rows of their books and series, and the rails: what they are reading,
/// what they hearted, what they finished, what waits on their pile. A rail
/// with nothing in it is not drawn. With more than one friend shown, each
/// cover says whose it is.
///
/// Without a friend, the page invites one: the reader's avatar among empty
/// places, and what their friends will see of their shelf.
struct FriendsPage: View {
    let friends: [Friend]
    let selected: [String]
    let shelf: FriendsShelf
    /// The one friend picked, whose library and series the rows open.
    let soleFriend: Friend?
    /// The reader's own shelf, for the page without a friend.
    let myShelf: FriendProfile?
    let hasNoFriend: Bool
    let isWaiting: Bool
    let loadFailed: String?
    let isInviting: Bool
    let onAction: (FriendsAction) async -> Void

    var body: some View {
        Group {
            if let loadFailed {
                EmptyState.failure("Impossible de charger vos amis", message: loadFailed) {
                    await onAction(.refresh)
                }
            } else if hasNoFriend {
                ScrollView { FriendsEmptyInvite(myShelf: myShelf, isInviting: isInviting, onAction: onAction) }
            } else {
                content
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle("Amis")
        .scrollAwayBar(String(localized: "Amis")) {
            if !hasNoFriend {
                ScrollBarButton(title: "Inviter", systemImage: "person.badge.plus") {
                    Task { await onAction(.invite) }
                }
            }
        }
        .refreshable { await onAction(.refresh) }
        .overlay(alignment: .top) {
            if isWaiting { ProgressView().padding(.top, 120) }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                VStack(alignment: .leading, spacing: 16) {
                    FriendAvatarPicker(
                        items: friends.map { .init(id: $0.userId, name: $0.displayName, avatar: $0.avatar) },
                        selected: selected
                    ) { id in Task { await onAction(.toggle(id)) } }
                    if let soleFriend {
                        VStack(spacing: 0) {
                            LibraryLinkRow(symbol: "book.pages", title: String(localized: "Livres")) {
                                Task { await onAction(.openLibrary(soleFriend)) }
                            }
                            LibraryLinkRow(symbol: "square.stack", title: String(localized: "Séries")) {
                                Task { await onAction(.openSeries(soleFriend)) }
                            }
                        }
                        .padding(.horizontal, 20)
                        .transition(.opacity)
                    }
                }
                .environment(\.colorScheme, .dark)
                rails
            }
            .padding(.top, 4)
            .padding(.bottom, 32)
            .animation(.smooth, value: selected)
            .background(alignment: .top) {
                CoverBackdrop(url: backdropURL, fadeHeight: 160, ground: Color(.systemBackground))
                    .frame(height: 760)
                    .offset(y: -300)
                    .animation(.smooth, value: backdropURL)
            }
        }
    }

    /// One friend shown speaks of them in the singular, several in the plural.
    private var isOne: Bool { soleFriend != nil }

    @ViewBuilder private var rails: some View {
        rail("Lecture en cours", shelf.reading, context: .recent)
        // The title says they are hearted: no heart, no line on the covers.
        rail("Coups de cœur récents", shelf.favorites, context: nil)
        rail("Terminés récemment", shelf.finished, context: .read)
        rail(isOne ? "Sur sa pile" : "Sur leur pile", shelf.pile, context: .pile)
    }

    @ViewBuilder
    private func rail(_ title: LocalizedStringKey, _ entries: [FriendsShelfEntry], context: PosterLabel.Context?) -> some View {
        if !entries.isEmpty {
            FriendsRail(
                title: title,
                items: entries.map { entry in
                    FriendsRail.Item(
                        id: entry.id,
                        book: entry.book.book,
                        label: context.map { PosterLabel.of(entry.book.book, in: $0) } ?? .bare,
                        friendName: isOne ? nil : (entry.friendName ?? String(localized: "Un lecteur")),
                        friendAvatar: entry.book.ownerAvatar
                    )
                }
            ) { item in
                if let entry = entries.first(where: { $0.id == item.id }) {
                    Task { await onAction(.openBook(entry)) }
                }
            }
        }
    }

    /// The colours under the avatars: the first book in progress, or the
    /// first of any rail.
    private var backdropURL: URL? {
        (shelf.reading.first ?? shelf.favorites.first ?? shelf.finished.first ?? shelf.pile.first)?.book.book.coverURL
    }
}

#Preview("Every friend") {
    NavigationStack {
        FriendsPage(
            friends: Friend.previews, selected: [], shelf: .preview, soleFriend: nil, myShelf: nil,
            hasNoFriend: false, isWaiting: false, loadFailed: nil, isInviting: false
        ) { _ in }
    }
}

#Preview("One friend") {
    NavigationStack {
        FriendsPage(
            friends: Friend.previews, selected: ["camille"], shelf: FriendsShelf.preview.narrowed(to: ["camille"]),
            soleFriend: Friend.previews[0], myShelf: nil,
            hasNoFriend: false, isWaiting: false, loadFailed: nil, isInviting: false
        ) { _ in }
    }
}

#Preview("No friend") {
    NavigationStack {
        FriendsPage(
            friends: [], selected: [], shelf: FriendsShelf(), soleFriend: nil, myShelf: .preview,
            hasNoFriend: true, isWaiting: false, loadFailed: nil, isInviting: false
        ) { _ in }
    }
}
