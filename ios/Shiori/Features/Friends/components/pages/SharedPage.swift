import SwiftUI

/// Where a row of the Partagé tab leads, pushed by the screen.
enum SharedDestination: Hashable {
    /// The reader's own page, as their friends see it.
    case myPage
    case friend(userId: String)
}

/// Everything the Partagé page can ask for.
enum SharedAction {
    /// A cover of a row: a friend's book, or the reader's own when `friend` is nil.
    case openBook(FriendBook, friend: Friend?)
    case invite
    case enterCode
    case askToRemove(Friend)
    case refresh
}

/// The Partagé tab, drawn: the reader at the top, as the row their friends
/// see in their own list, then who the reader shares their library with,
/// each friend with their shelf in figures and what moved on it lately.
///
/// Sharing is symmetric and the page says so plainly rather than leaving it
/// to be discovered: accepting an invitation opens both shelves at once, and
/// either of the two can end it for both.
struct SharedPage: View {
    let myShelf: FriendProfile?
    let friends: [Friend]
    /// Nothing is on screen and the server has not answered yet.
    let isWaiting: Bool
    /// The list could not be read, with nothing else to show.
    let loadFailed: String?
    let isInviting: Bool
    let onAction: (SharedAction) async -> Void

    var body: some View {
        content.refreshable { await onAction(.refresh) }
    }

    @ViewBuilder
    private var content: some View {
        if let loadFailed {
            EmptyState.failure("Amis indisponibles", message: loadFailed) { await onAction(.refresh) }
        } else if isWaiting {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                if let myShelf {
                    mySection(myShelf)
                }
                // Only a race once there is somebody to race against.
                if let myShelf, !friends.isEmpty {
                    Section {
                        ReadingChallengeCard(
                            challenge: ReadingChallenge(me: Friend(seenByFriends: myShelf), friends: friends)
                        )
                    } header: {
                        Text("Défi lecture \(String(Calendar.current.component(.year, from: .now)))")
                    }
                }
                if friends.isEmpty {
                    invitePrompt
                } else {
                    friendsSection
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private func mySection(_ myShelf: FriendProfile) -> some View {
        Section {
            NavigationLink(value: SharedDestination.myPage) {
                FriendRow(friend: Friend(seenByFriends: myShelf)) { book in
                    Task { await onAction(.openBook(book, friend: nil)) }
                }
            }
            .navigationLinkIndicatorVisibility(.hidden)
            .listRowInsets(.horizontal, 16)
            // Inset from the avatar: the line under a card, above the
            // action that goes with it, not the break between friends.
            .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
            .accessibilityIdentifier("shared-my-page")
            if let favorites = FavoritesSharing.text(of: myShelf) {
                Menu {
                    FavoritesShareItems(text: favorites)
                } label: {
                    Label("Partager mes favoris", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("shared-share-favorites")
            }
        } header: {
            Text("Vous")
        }
    }

    private var friendsSection: some View {
        Section {
            AsyncButton {
                await onAction(.invite)
            } label: {
                Label("Envoyer une invitation", systemImage: "person.badge.plus")
            }
            .disabled(isInviting)
            .accessibilityIdentifier("friends-invite")
            ForEach(friends) { friend in
                NavigationLink(value: SharedDestination.friend(userId: friend.userId)) {
                    FriendRow(friend: friend) { book in
                        Task { await onAction(.openBook(book, friend: friend)) }
                    }
                }
                .navigationLinkIndicatorVisibility(.hidden)
                // The reader's own row's margin, so the covers keep the same
                // size from one card to the next.
                .listRowInsets(.horizontal, 16)
                .edgeToEdgeSeparator()
                .swipeActions {
                    Button("Retirer", role: .destructive) {
                        Task { await onAction(.askToRemove(friend)) }
                    }
                }
                .accessibilityIdentifier("shared-friend-row")
            }
        } header: {
            Text("Mes amis")
        }
    }

    /// Nobody to share with yet: what sharing does, and the two ways in.
    private var invitePrompt: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("Partagez vos lectures").font(.headline)
                Text("Invitez un ami : vous verrez sa bibliothèque et il verra la vôtre. Chacun pourra piocher des livres chez l'autre.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            AsyncButton {
                await onAction(.invite)
            } label: {
                Label("Inviter un ami", systemImage: "person.badge.plus")
            }
            AsyncButton {
                await onAction(.enterCode)
            } label: {
                Label("J'ai reçu une invitation", systemImage: "arrow.down.circle")
            }
        }
    }
}

#Preview("With friends") {
    NavigationStack {
        SharedPage(
            myShelf: .preview, friends: Friend.previews, isWaiting: false, loadFailed: nil,
            isInviting: false
        ) { _ in }
            .navigationTitle("Partagé")
    }
}

#Preview("No friend yet") {
    NavigationStack {
        SharedPage(myShelf: .preview, friends: [], isWaiting: false, loadFailed: nil, isInviting: false) { _ in }
            .navigationTitle("Partagé")
    }
}

#Preview("Failed") {
    SharedPage(
        myShelf: nil, friends: [], isWaiting: false, loadFailed: "Le serveur ne répond pas.",
        isInviting: false
    ) { _ in }
}
