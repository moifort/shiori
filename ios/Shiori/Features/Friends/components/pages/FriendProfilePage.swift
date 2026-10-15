import SwiftUI

/// Everything a friend's page can ask for.
enum FriendProfileAction {
    case openBook(FriendBook)
    case refresh
}

/// Where a friend's page leads, pushed by the screen.
enum FriendProfileDestination: Hashable {
    /// The whole library, behind the last line.
    case library
}

/// One friend's shelf, summed up as Découvrir sums up its books: one card —
/// their hearts, newest first; their pile, the last added first, each over a
/// strip of its covers; last, their whole library behind a line that opens it.
/// Each line says how many books it stands for.
///
/// Read-only as far as the friend's library goes. Books they marked "do not
/// share" are absent, and no reading note is drawn: a friend sees a shelf,
/// not a diary.
struct FriendProfilePage: View {
    let friend: Friend
    let profile: FriendProfile?
    /// The reader's own page, as their friends see it.
    let isPreview: Bool
    let isLoading: Bool
    let errorMessage: String?
    let onAction: (FriendProfileAction) async -> Void

    var body: some View {
        Group {
            if isLoading && profile == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let profile, !profile.isEmpty {
                shelves(profile)
            } else if let errorMessage {
                EmptyStateView.failure("Bibliothèque indisponible", message: errorMessage) {
                    await onAction(.refresh)
                }
            } else {
                Text("Aucun livre n'a été ajouté à cette bibliothèque.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(profile?.displayName ?? friend.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { if isPreview { shareFavorites } }
    }

    private func shelves(_ profile: FriendProfile) -> some View {
        List {
            // The shelf at a glance, as Découvrir sums up its books: the hearts
            // and the pile, each over a strip of its covers, a tap opening the
            // book, then the whole library behind the last line.
            Section {
                if !profile.favorites.isEmpty {
                    DiscoverSummaryRow(
                        title: isPreview ? "Mes favoris" : "Ses favoris",
                        systemImage: "heart.fill",
                        tint: .red,
                        line: countLine(friend.favoriteCount)
                    ) {
                        covers(profile.favorites)
                    }
                    .accessibilityIdentifier("friend-favorites")
                }
                if !profile.pile.isEmpty {
                    DiscoverSummaryRow(
                        title: isPreview ? "Ma pile à lire" : "Sa pile à lire",
                        systemImage: "bookmark.fill",
                        tint: ReadingStatus.toRead.tint,
                        line: countLine(friend.toReadCount)
                    ) {
                        covers(profile.pile)
                    }
                    .accessibilityIdentifier("friend-pile")
                }
                NavigationLink(value: FriendProfileDestination.library) {
                    DiscoverSummaryRow(title: "Bibliothèque", line: libraryLine(profile))
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 16))
                .accessibilityIdentifier("friend-see-library")
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await onAction(.refresh) }
    }

    /// The preview keeps what the favourites list used to offer: the whole
    /// list as text, for a mail, a message, or the clipboard.
    @ToolbarContentBuilder
    private var shareFavorites: some ToolbarContent {
        if let profile, let text = FavoritesSharing.text(of: profile) {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    FavoritesShareItems(text: text)
                } label: {
                    Label("Partager mes favoris", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("my-shelf-share-favorites")
            }
        }
    }

    /// "2 séries · 80 livres · 3 en cours", the sagas and the books in
    /// progress left out when there are none.
    private func libraryLine(_ profile: FriendProfile) -> String {
        var parts: [String] = []
        if !profile.sagas.isEmpty {
            parts.append(inflected("^[\(profile.sagas.count) série](inflect: true)"))
        }
        parts.append(inflected("^[\(profile.bookCount) livre](inflect: true)"))
        if friend.readingCount > 0 {
            parts.append(String(localized: "\(friend.readingCount) en cours"))
        }
        return parts.joined(separator: " · ")
    }

    /// "4 livres".
    private func countLine(_ count: Int) -> String {
        inflected("^[\(count) livre](inflect: true)")
    }

    /// The words agreed with their number: only an attributed string carries
    /// out the inflection its markdown asks for.
    private func inflected(_ resource: String.LocalizationValue) -> String {
        String(AttributedString(localized: resource).characters)
    }

    /// The covers of a summary line, newest first as the server sends them,
    /// each opening the book.
    private func covers(_ books: [FriendBook]) -> some View {
        ForEach(books) { entry in
            Button { Task { await onAction(.openBook(entry)) } } label: {
                BookCover(
                    book: entry.book,
                    width: CoverTile.summaryWidth,
                    formatBadgeSize: CoverTile.formatBadgeSize
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(entry.book.title)
            .accessibilityIdentifier("friend-book-cover")
        }
    }
}

#Preview("Friend's shelf") {
    NavigationStack {
        FriendProfilePage(
            friend: Friend.previews[0], profile: .preview, isPreview: false, isLoading: false,
            errorMessage: nil
        ) { _ in }
    }
}

#Preview("My shelf, previewed") {
    NavigationStack {
        FriendProfilePage(
            friend: Friend(seenByFriends: .preview), profile: .preview, isPreview: true,
            isLoading: false, errorMessage: nil
        ) { _ in }
    }
}

#Preview("Empty") {
    NavigationStack {
        FriendProfilePage(
            friend: Friend.previews[1], profile: nil, isPreview: false, isLoading: false,
            errorMessage: nil
        ) { _ in }
    }
}
