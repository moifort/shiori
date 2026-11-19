import SwiftUI

/// Whose book it is, in the top corner of a cover: the friend's avatar and
/// first name on a dark glass capsule, white like every label on a cover.
struct FriendCoverTag: View {
    let name: String
    let avatar: AccountAvatar

    var body: some View {
        HStack(spacing: 5) {
            AccountAvatarView(avatar: avatar, firstName: name, size: 18)
            Text(name)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.leading, 4)
        .padding(.trailing, 9)
        .frame(height: 26)
        .background(.black.opacity(0.35), in: .capsule)
        .background(.ultraThinMaterial, in: .capsule)
        .overlay { Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 0.5) }
        .environment(\.colorScheme, .dark)
    }
}

#Preview {
    FriendCoverTag(name: "Sophie", avatar: .hero(.alice))
        .padding()
        .background(.orange)
}
