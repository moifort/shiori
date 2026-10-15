import SwiftUI

/// A friend's book, connected: loads it, what Audible sells and what may be
/// awaited of it, takes it onto the reader's shelf from the "+" in the corner,
/// pushes its saga, and hands the rest to `FriendBookPage`.
///
/// Always opened as a sheet, as a book opens from the reader's own library:
/// a close button in the corner.
struct FriendBookScreen: View {
    let friendName: String
    /// Called once the book is on the reader's shelf, so the screen that
    /// opened this one can say "Chez vous" without asking again.
    var onAdded: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: FriendBookViewModel
    @State private var showsSaga = false
    @State private var openAwaited: AwaitedEdition?

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
                    awaited: viewModel.offer.awaited
                ) { action in
                    switch action {
                    case .openSeries: showsSaga = true
                    case let .openAwaited(edition): openAwaited = edition
                    case let .stopAwaiting(edition): await viewModel.stopAwaiting(edition)
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
        .navigationTitle(Text(verbatim: String(localized: "Chez \(friendName)")))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .task { await viewModel.loadAudio() }
        .task { await viewModel.loadOffer() }
        .sheet(item: $openAwaited) { edition in
            NavigationStack {
                AwaitedEditionScreen(edition: edition) {
                    Task { await viewModel.stopAwaiting(edition) }
                }
            }
        }
        .navigationDestination(isPresented: $showsSaga) {
            if let series = viewModel.entry?.book.series {
                SeriesScreen(
                    seriesId: series.id,
                    language: viewModel.entry?.book.language,
                    friend: SeriesFriend(id: viewModel.friendId, name: friendName)
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) { dismiss() }
            }
            if let entry = viewModel.entry {
                ToolbarItem(placement: .primaryAction) {
                    FriendBookAddMenu(
                        formats: entry.book.format.takenAs.filter { $0 != .audiobook || viewModel.audio != .unavailable },
                        owned: entry.inLibrary || viewModel.added != nil,
                        awaitable: viewModel.offer.awaitable,
                        onAdd: { status, format in
                            if await viewModel.add(status, as: format) { onAdded() }
                        },
                        onAwait: { viewModel.awaitEdition($0) }
                    )
                }
            }
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
