import SwiftUI

/// Who the reader shares their library with.
///
/// Sharing is symmetric and the screen says so plainly rather than leaving it
/// to be discovered: accepting an invitation opens both shelves at once, and
/// either of the two can end it for both. There is nothing to approve on the
/// other side and no half-state to explain.
struct FriendsView: View {
    @State private var friends: [Friend] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var invitation: FriendInvitation?
    @State private var showAccept = false
    @State private var pastedCode = ""
    @State private var accepted: String?
    @State private var removing: Friend?

    var body: some View {
        List {
            if isLoading && friends.isEmpty {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
            } else if friends.isEmpty {
                Section {
                    Text("Personne pour l'instant. Invitez quelqu'un, ou acceptez son invitation : vous verrez sa bibliothèque et il verra la vôtre.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("Vos amis") {
                    ForEach(friends) { friend in
                        NavigationLink {
                            FriendProfileView(friend: friend)
                        } label: {
                            row(friend)
                        }
                        .swipeActions {
                            Button("Retirer", role: .destructive) { removing = friend }
                        }
                    }
                }
            }

            Section {
                AsyncButton("Inviter un ami", systemImage: "person.badge.plus") { await invite() }
                    .accessibilityIdentifier("friends-invite")
                Button {
                    pastedCode = ""
                    showAccept = true
                } label: {
                    Label("J'ai reçu une invitation", systemImage: "arrow.down.circle")
                }
                .accessibilityIdentifier("friends-accept")
            } footer: {
                Text("Un ami voit vos lectures en cours, votre pile, vos favoris et vos séries. Jamais vos notes de lecture, ni les livres que vous avez marqués « ne pas partager ».")
            }
        }
        .navigationTitle("Amis")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
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

    private func row(_ friend: Friend) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName)
                Text("depuis le \(friend.since.formatted(date: .abbreviated, time: .omitted))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "person.crop.circle.fill")
                .foregroundStyle(.secondary)
        }
    }

    private func load() async {
        isLoading = true
        do {
            friends = try await FriendsAPI.friends()
        } catch {
            errorMessage = reportError(error)
        }
        isLoading = false
    }

    private func invite() async {
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
            await load()
        } catch {
            errorMessage = reportError(error)
        }
    }

    private func remove(_ friend: Friend) async {
        removing = nil
        do {
            try await FriendsAPI.remove(userId: friend.userId)
            await load()
        } catch {
            errorMessage = reportError(error)
        }
    }
}

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
    NavigationStack { FriendsView() }
}
