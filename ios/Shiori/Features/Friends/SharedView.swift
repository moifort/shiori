import SwiftUI

/// The Partagé tab: the reader at the top, drawn as the row their friends see
/// in their own list and opening on their page exactly as it is shown to them,
/// then who the reader shares their library with, each friend
/// with their shelf in figures — favourites, books in progress, pile — and the
/// book they are reading. A friend opens on their shelf, where any book can be
/// taken onto the reader's own.
///
/// Sharing is symmetric and the screen says so plainly rather than leaving it
/// to be discovered: accepting an invitation opens both shelves at once, and
/// either of the two can end it for both. There is nothing to approve on the
/// other side and no half-state to explain.
struct SharedView: View {
    @State private var friends: [Friend] = []
    @State private var myShelf: FriendProfile?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var loadFailed: String?
    @State private var invitation: FriendInvitation?
    @State private var showAccept = false
    @State private var pastedCode = ""
    @State private var accepted: String?
    @State private var removing: Friend?
    @State private var isInviting = false
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("Partagé")
                .toolbar { toolbar }
                .navigationDestination(for: Friend.ID.self) { userId in
                    if let friend = friends.first(where: { $0.userId == userId }) {
                        FriendProfileView(friend: friend)
                    }
                }
                .navigationDestination(for: MyPagePreview.self) { _ in
                    if let myShelf {
                        FriendProfileView(preview: myShelf)
                    }
                }
        }
        .task { await load() }
        .refreshable { await load() }
        // A book taken from a friend changes what "Chez vous" says on their
        // shelves, and their counts move when they write: asked again on the
        // next look.
        .onReceive(NotificationCenter.default.publisher(for: .shioriDataDidChange)) { _ in
            Task { await load() }
        }
        // The invitation is shared the moment it comes back: the reader tapped
        // "invite", and a code sitting on screen with nothing to do is a step
        // they did not ask for.
        .sheet(item: $invitation) { invitation in
            InvitationSheet(invitation: invitation)
        }
        .alert("J'ai reçu une invitation", isPresented: $showAccept) {
            TextField("Code ou lien", text: $pastedCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            Button("Annuler", role: .cancel) {}
            Button("Accepter") { Task { await accept() } }
        } message: {
            Text("Collez le code à huit caractères, ou le lien que l'on vous a envoyé.")
        }
        .alert(
            "Vous partagez vos bibliothèques",
            isPresented: .init(get: { accepted != nil }, set: { if !$0 { accepted = nil } })
        ) {
            Button("Parfait", role: .cancel) { accepted = nil }
        } message: {
            Text("\(accepted ?? "") voit votre bibliothèque, et vous voyez la sienne.")
        }
        .alert(
            "Une erreur est survenue",
            isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .confirmationDialog(
            "Ne plus partager avec \(removing?.displayName ?? "") ?",
            isPresented: .init(get: { removing != nil }, set: { if !$0 { removing = nil } }),
            titleVisibility: .visible
        ) {
            Button("Retirer", role: .destructive) {
                if let friend = removing { Task { await remove(friend) } }
            }
            Button("Annuler", role: .cancel) { removing = nil }
        } message: {
            Text("Vous ne verrez plus sa bibliothèque, et il ne verra plus la vôtre.")
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && friends.isEmpty && myShelf == nil {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let loadFailed, friends.isEmpty, myShelf == nil {
            EmptyStateView.failure("Amis indisponibles", message: loadFailed) { await load() }
        } else {
            List {
                if let myShelf {
                    Section {
                        // Tapped rather than linked, as a book row carrying its
                        // "+": a link would swallow the share button's tap.
                        row(Friend(seenByFriends: myShelf), name: "Vous", sharing: favoritesText(myShelf))
                            .contentShape(.rect)
                            .onTapGesture { path.append(MyPagePreview()) }
                            .accessibilityAddTraits(.isButton)
                            .edgeToEdgeSeparator()
                            .accessibilityIdentifier("shared-my-page")
                    } header: {
                        Text("Vous")
                    }
                }
                if friends.isEmpty {
                    invitePrompt
                } else {
                    Section {
                        ForEach(friends) { friend in
                            NavigationLink(value: friend.userId) {
                                row(friend)
                            }
                            .navigationLinkIndicatorVisibility(.hidden)
                            .edgeToEdgeSeparator()
                            .swipeActions {
                                Button("Retirer", role: .destructive) { removing = friend }
                            }
                            .accessibilityIdentifier("shared-friend-row")
                        }
                    } header: {
                        Text("Mes amis")
                    } footer: {
                        Text("Un ami voit vos lectures en cours, votre pile, vos favoris et vos séries. Jamais vos notes de lecture, ni les livres que vous avez marqués « ne pas partager ».")
                    }
                }
            }
            .listStyle(.insetGrouped)
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
            Button {
                Task { await invite() }
            } label: {
                Label("Inviter un ami", systemImage: "person.badge.plus")
            }
            Button {
                pastedCode = ""
                showAccept = true
            } label: {
                Label("J'ai reçu une invitation", systemImage: "arrow.down.circle")
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    Task { await invite() }
                } label: {
                    Label("Inviter un ami", systemImage: "person.badge.plus")
                }
                .accessibilityIdentifier("friends-invite")
                Button {
                    pastedCode = ""
                    showAccept = true
                } label: {
                    Label("J'ai reçu une invitation", systemImage: "arrow.down.circle")
                }
                .accessibilityIdentifier("friends-accept")
            } label: {
                if isInviting {
                    ProgressView()
                } else {
                    Label("Ajouter un ami", systemImage: "person.badge.plus")
                }
            }
            .accessibilityIdentifier("shared-add-friend")
        }
    }

    /// A friend as the list draws them: the name, their shelf in figures in
    /// the top corner as a book row carries its marks, and the book they are
    /// reading. `name` stands in for theirs on the reader's own row, "Vous",
    /// which also carries in the bottom corner the favourites to share,
    /// `sharing`, when there are any.
    private func row(
        _ friend: Friend,
        name: LocalizedStringKey? = nil,
        sharing favorites: String? = nil
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(friend.initials)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 40, height: 40)
                .background(.tint.opacity(0.15), in: .circle)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Group {
                        if let name { Text(name) } else { Text(friend.displayName) }
                    }
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                    Spacer(minLength: 0)
                    HStack(spacing: 10) {
                        Label("\(friend.favoriteCount)", systemImage: "heart")
                            .accessibilityLabel(Text("\(friend.favoriteCount) favoris"))
                        Label("\(friend.readingCount)", systemImage: "book")
                            .accessibilityLabel(Text("\(friend.readingCount) en cours"))
                        Label("\(friend.toReadCount)", systemImage: "books.vertical")
                            .accessibilityLabel(Text("\(friend.toReadCount) à lire"))
                    }
                    .labelStyle(.caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize()
                }
                if friend.readingTitle != nil || favorites != nil {
                    HStack(alignment: .center, spacing: 8) {
                        if let title = friend.readingTitle {
                            Text("Lit : \(title)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        if let favorites { shareButton(favorites) }
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    /// The favourites as text, as the preview page's toolbar sends them; nil
    /// when nothing is hearted and there is nothing to send.
    private func favoritesText(_ shelf: FriendProfile) -> String? {
        guard !(shelf.favoriteSagas.isEmpty && shelf.favorites.isEmpty) else { return nil }
        return FavoritesSharing.text(sagas: shelf.favoriteSagas, books: shelf.favorites.map(\.book))
    }

    /// The share icon drawn as a row's "+" is: a small circle in the accent
    /// colour, opening the same entries as the preview page's toolbar.
    private func shareButton(_ favorites: String) -> some View {
        Menu {
            FavoritesShareItems(text: favorites)
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.caption.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .controlSize(.small)
        .accessibilityLabel(Text("Partager mes favoris"))
        .accessibilityIdentifier("shared-share-favorites")
    }

    private func load() async {
        isLoading = true
        // The two reads are independent: the preview still opens when the
        // friends list fails, and the other way round.
        async let shelf = FriendsAPI.myShelf()
        do {
            friends = try await FriendsAPI.friends()
            loadFailed = nil
        } catch {
            loadFailed = reportError(error)
        }
        do {
            myShelf = try await shelf
        } catch {
            _ = reportError(error)
        }
        isLoading = false
    }

    private func invite() async {
        isInviting = true
        defer { isInviting = false }
        do {
            invitation = try await FriendsAPI.invite()
        } catch {
            errorMessage = reportError(error)
        }
    }

    private func accept() async {
        let code = pastedCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }
        do {
            let friend = try await FriendsAPI.accept(code: code)
            accepted = friend.displayName
            // The answer is the new row: filed where the server files it, by
            // first name, rather than read back with the whole list.
            friends = (friends.filter { $0.userId != friend.userId } + [friend])
                .sorted { ($0.firstName ?? "").localizedCompare($1.firstName ?? "") == .orderedAscending }
        } catch {
            errorMessage = reportError(error)
        }
    }

    private func remove(_ friend: Friend) async {
        removing = nil
        do {
            try await FriendsAPI.remove(userId: friend.userId)
            friends.removeAll { $0.userId == friend.userId }
        } catch {
            errorMessage = reportError(error)
        }
    }
}

/// The navigation value of the reader's own page, previewed.
private struct MyPagePreview: Hashable {}

extension FriendInvitation: Identifiable {
    var id: String { code }
}

/// The invitation, ready to send. The link is what gets shared — it lands on a
/// page that says what to do with the code, so it means something to somebody
/// who does not have Shiori yet — and the code is spelled out underneath for
/// reading down a phone.
private struct InvitationSheet: View {
    let invitation: FriendInvitation
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "person.2.badge.key")
                    .font(.system(size: 44))
                    .foregroundStyle(.tint)

                Text(invitation.code)
                    .font(.system(.largeTitle, design: .monospaced, weight: .bold))
                    .kerning(6)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
                    .textSelection(.enabled)
                    .accessibilityIdentifier("invitation-code")

                Text("Envoyez ce lien. Celui qui l'ouvre verra votre bibliothèque, et vous verrez la sienne.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                ShareLink(
                    item: invitation.url,
                    subject: Text("Ma bibliothèque sur Shiori"),
                    message: Text("Je t'ouvre ma bibliothèque sur Shiori. Code : \(invitation.code)")
                ) {
                    Label("Envoyer l'invitation", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)

                Text("Valable jusqu'au \(invitation.expiresAt.formatted(date: .long, time: .omitted)). Une seule personne peut l'utiliser.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("Inviter un ami")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    SharedView()
}
