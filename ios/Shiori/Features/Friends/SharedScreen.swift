import SwiftUI

/// The Partagé tab, connected: loads the reader's shelf and their friends,
/// opens a friend's page, a book, the invitation flows, and hands the rest to
/// `SharedPage`.
///
/// The tab opens on what it last showed, brought up to date silently underneath.
struct SharedScreen: View {
    @State private var viewModel: SharedViewModel
    @State private var showAccept = false
    @State private var pastedCode = ""
    @State private var removing: Friend?
    @State private var openedBook: OpenedBook?

    init(client: FriendsClient = .live) {
        _viewModel = State(initialValue: SharedViewModel(client: client))
    }

    var body: some View {
        NavigationStack {
            SharedPage(
                myShelf: viewModel.myShelf,
                friends: viewModel.friends,
                isWaiting: viewModel.isEmpty && !viewModel.loaded,
                loadFailed: viewModel.isEmpty && !viewModel.isLoading ? viewModel.loadFailed : nil,
                isInviting: viewModel.isInviting
            ) { action in
                switch action {
                case let .openBook(book, friend): openedBook = OpenedBook(book: book, friend: friend)
                case .invite: await viewModel.invite()
                case .enterCode:
                    pastedCode = ""
                    showAccept = true
                case let .askToRemove(friend): removing = friend
                case .refresh: await viewModel.load()
                }
            }
            .navigationTitle("Partagé")
            .navigationDestination(for: SharedDestination.self) { destination in
                switch destination {
                case .myPage:
                    if let myShelf = viewModel.myShelf {
                        FriendProfileScreen(preview: myShelf)
                    }
                case let .friend(userId):
                    if let friend = viewModel.friends.first(where: { $0.userId == userId }) {
                        FriendProfileScreen(friend: friend)
                    }
                }
            }
        }
        .task { await viewModel.loadOnAppear() }
        // A book taken from a friend changes what "Chez vous" says on their
        // shelves, and their counts move when they write: asked again on the
        // next look.
        .onReceive(NotificationCenter.default.publisher(for: .shioriDataDidChange)) { _ in
            Task { await viewModel.load() }
        }
        // The invitation is shared the moment it comes back: the reader tapped
        // "invite", and a code sitting on screen with nothing to do is a step
        // they did not ask for.
        .sheet(item: $viewModel.invitation) { invitation in
            InvitationSheet(invitation: invitation, myShelf: viewModel.myShelf)
        }
        // A cover opens its book as the friend's page opens it; the reader's
        // own covers open their own record.
        .sheet(item: $openedBook) { opened in
            if let friend = opened.friend {
                NavigationStack {
                    FriendBookScreen(friendId: friend.userId, bookId: opened.book.id, friendName: friend.displayName)
                }
            } else {
                BookView(bookId: opened.book.id)
            }
        }
        .alert("J'ai reçu une invitation", isPresented: $showAccept) {
            TextField("Code ou lien", text: $pastedCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            Button("Annuler", role: .cancel) {}
            Button("Accepter") { Task { await viewModel.accept(code: pastedCode) } }
        } message: {
            Text("Collez le code à huit caractères, ou le lien que l'on vous a envoyé.")
        }
        .alert(
            "Vous partagez vos bibliothèques",
            isPresented: .init(
                get: { viewModel.accepted != nil },
                set: { if !$0 { viewModel.accepted = nil } }
            )
        ) {
            Button("Parfait", role: .cancel) { viewModel.accepted = nil }
        } message: {
            Text("\(viewModel.accepted ?? "") voit votre bibliothèque, et vous voyez la sienne.")
        }
        .alert(
            "Une erreur est survenue",
            isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .confirmationDialog(
            "Ne plus partager avec \(removing?.displayName ?? "") ?",
            isPresented: .init(get: { removing != nil }, set: { if !$0 { removing = nil } }),
            titleVisibility: .visible
        ) {
            Button("Retirer", role: .destructive) {
                if let friend = removing {
                    removing = nil
                    Task { await viewModel.remove(friend) }
                }
            }
            Button("Annuler", role: .cancel) { removing = nil }
        } message: {
            Text("Vous ne verrez plus sa bibliothèque, et il ne verra plus la vôtre.")
        }
    }
}

/// A book opened from a cover of the list: a friend's, or the reader's own
/// when the friend is nil.
private struct OpenedBook: Identifiable {
    let book: FriendBook
    let friend: Friend?

    var id: String { book.id }
}

extension FriendInvitation: Identifiable {
    var id: String { code }
}

#Preview {
    SharedScreen(client: .preview)
}
