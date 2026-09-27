import SwiftUI

/// An invitation the reader arrived on by tapping a link, waiting to be taken up.
struct InvitationRequest: Identifiable, Equatable {
    let code: String
    var id: String { code }
}

/// What a tapped invitation link opens on.
///
/// It asks before it accepts. The link came from somewhere the reader does not
/// control — a message, a forwarded mail, a page — and accepting opens their
/// library to whoever sent it. One tap to arrive here is right; one tap to share
/// a library is not.
struct InvitationAcceptSheet: View {
    let request: InvitationRequest
    let onAccepted: () -> Void

    @Environment(\.dismiss) private var dismiss
    /// The reader's shelf as the sender will see it: what accepting shares.
    @State private var myShelf: FriendProfile?
    @State private var accepted: Friend?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Image(systemName: accepted == nil ? "person.2.badge.key" : "checkmark.seal.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                if let accepted {
                    Text("Vous partagez maintenant vos livres")
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                    SharedSummary(friend: accepted, heading: nil)
                    Spacer(minLength: 0)
                    Button("Parfait") { dismiss() }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Vous partagerez vos livres")
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                    if let myShelf {
                        SharedSummary(friend: Friend(seenByFriends: myShelf), heading: nil)
                    }
                    Spacer(minLength: 0)
                    AsyncButton("Accepter") { await accept() }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("invitation-accept")
                    Button("Pas maintenant") { dismiss() }
                        .font(.subheadline)
                }
            }
            .padding(28)
            .navigationTitle("Invitation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) {
                        dismiss()
                    }
                }
            }
            .alert(
                "Invitation refusée",
                isPresented: .init(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .presentationDetents([.medium])
        // The summary is a nicety: the invitation can be accepted without it.
        .task { myShelf = try? await FriendsAPI.myShelf() }
    }

    private func accept() async {
        do {
            accepted = try await FriendsAPI.accept(code: request.code)
            // The Partagé tab reloads on the notice, so the new friend is
            // already in the list when the reader gets there.
            NotificationCenter.default.post(name: .shioriDataDidChange, object: nil)
            onAccepted()
        } catch {
            errorMessage = reportError(error)
        }
    }
}
