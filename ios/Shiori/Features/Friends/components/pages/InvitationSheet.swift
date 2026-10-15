import SwiftUI

/// The invitation, ready to send. The link is what gets shared — it lands on a
/// page that says what to do with the code, so it means something to somebody
/// who does not have Shiori yet — and the code is spelled out underneath for
/// reading down a phone.
struct InvitationSheet: View {
    let invitation: FriendInvitation
    /// The reader's shelf as the friend will see it; nil while it has not
    /// loaded yet, and the row is then left out.
    let myShelf: FriendProfile?
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

                if let myShelf {
                    SharedSummary(friend: Friend(seenByFriends: myShelf))
                }

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
    Color.clear.sheet(isPresented: .constant(true)) {
        InvitationSheet(invitation: .preview, myShelf: .preview)
    }
}
