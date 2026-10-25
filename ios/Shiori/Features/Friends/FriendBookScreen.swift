import SwiftUI

/// A friend's book, connected: loads it, what Audible sells and what may be
/// awaited of it, takes it onto the reader's shelf from the hero's first
/// button, pushes its saga, and hands the rest to `FriendBookPage`.
///
/// Always opened as a sheet, as a book opens from the reader's own library:
/// a close button in the corner.
struct FriendBookScreen: View {
    let friendName: String
    /// Called once the book is on the reader's shelf, so the screen that
    /// opened this one can say "Chez vous" without asking again.
    var onAdded: () -> Void = {}

    @Environment(\.dismiss) private var dismissPresentation
    @Environment(\.detailClosing) private var closing

    /// Pops the screen, closes its sheet, or empties the detail column it
    /// fills on an unfolded iPhone Duo.
    private func dismiss() { closing.close(dismissPresentation) }

    @State private var viewModel: FriendBookViewModel
    @State private var showsSaga = false
    @State private var openAwaited: AwaitedEdition?
    @State private var openAuthor: AuthorDestination?

    init(
        friendId: String,
        bookId: String,
        friendName: String,
        onAdded: @escaping () -> Void = {},
        client: FriendsClient = .live
    ) {
        self.friendName = friendName
        self.onAdded = onAdded
        _viewModel = State(initialValue: FriendBookViewModel(friendId: friendId, bookId: bookId, client: client))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.entry == nil {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let entry = viewModel.entry {
                FriendBookPage(
                    entry: entry,
                    friendId: viewModel.friendId,
                    friendName: friendName,
                    added: viewModel.added,
                    awaited: viewModel.offer.awaited,
                    formats: entry.book.format.takenAs.filter { $0 != .audiobook || viewModel.audio != .unavailable },
                    awaitable: viewModel.offer.awaitable
                ) { action in
                    switch action {
                    case .openSeries: showsSaga = true
                    case let .openAuthor(author): openAuthor = author
                    case let .openAwaited(edition): openAwaited = edition
                    case let .stopAwaiting(edition): await viewModel.stopAwaiting(edition)
                    case let .add(status, format):
                        if await viewModel.add(status, as: format) { onAdded() }
                    case let .awaitEdition(format): viewModel.awaitEdition(format)
                    }
                }
            } else if let errorMessage = viewModel.errorMessage {
                EmptyState.failure("Livre indisponible", message: errorMessage) { await viewModel.load() }
            } else {
                EmptyState(
                    systemImage: "book.closed",
                    title: "Livre introuvable",
                    message: "Ce livre n'est plus partagé."
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .task { await viewModel.loadAudio() }
        .task { await viewModel.loadOffer() }
        // Offered as Découvrir offers a friend's loved author: the reader may
        // hold nothing of theirs, and the page then lists it all to add.
        .pushesDetail(item: $openAuthor) { author in
            AuthorScreen(key: author.key, name: author.name, isOffered: true)
        }
        .pushesDetail(item: $openAwaited) { edition in
            AwaitedEditionScreen(edition: edition) {
                Task { await viewModel.stopAwaiting(edition) }
            }
        }
        .navigationDestination(isPresented: $showsSaga) {
            if let series = viewModel.entry?.book.series {
                SeriesScreen(
                    seriesId: series.id,
                    language: viewModel.entry?.book.language,
                    friend: SeriesFriend(id: viewModel.friendId, name: friendName)
                )
                .closesAsPushed()
            }
        }
        .toolbar {
            if closing.showsCloseButton {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) { dismiss() }
                }
            }
            // Whose shelf it is: their disc in the corner, as the TV app
            // sets the account's — filling the place, without the toolbar's
            // glass around it. Their name is on the hero's detail line.
            ToolbarItem(placement: .primaryAction) {
                FriendMonogram(name: friendName)
                    .accessibilityLabel(Text("Chez \(friendName)"))
                    .accessibilityIdentifier("friend-book-owner")
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .alert(
            "Ajout impossible",
            isPresented: .init(
                get: { viewModel.addFailed != nil },
                set: { if !$0 { viewModel.addFailed = nil } }
            )
        ) {
            Button("OK", role: .cancel) { viewModel.addFailed = nil }
        } message: {
            Text(viewModel.addFailed ?? "")
        }
    }
}

#Preview {
    NavigationStack {
        FriendBookScreen(friendId: "camille", bookId: "preview", friendName: "Camille", client: .preview)
    }
}
