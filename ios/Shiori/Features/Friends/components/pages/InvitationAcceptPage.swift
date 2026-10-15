import SwiftUI

/// Everything the invitation page can ask for.
enum InvitationAcceptAction {
    case accept
    case close
}

/// An invitation opened from a link: what accepting shares, and once accepted,
/// the friend it joined.
struct InvitationAcceptPage: View {
    /// The reader's shelf as the sender will see it; nil while unknown, and
    /// the summary is then left out.
    let myShelf: FriendProfile?
    let accepted: Friend?
    let onAction: (InvitationAcceptAction) async -> Void

    var body: some View {
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
                AsyncButton("Parfait") { await onAction(.close) }
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
                AsyncButton("Accepter") { await onAction(.accept) }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("invitation-accept")
                AsyncButton("Pas maintenant") { await onAction(.close) }
                    .font(.subheadline)
            }
        }
        .padding(28)
        .navigationTitle("Invitation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) {
                    Task { await onAction(.close) }
                }
            }
        }
    }
}

#Preview("Before accepting") {
    NavigationStack {
        InvitationAcceptPage(myShelf: .preview, accepted: nil) { _ in }
    }
}

#Preview("Accepted") {
    NavigationStack {
        InvitationAcceptPage(myShelf: .preview, accepted: Friend.previews[1]) { _ in }
    }
}
