import SwiftUI

/// Whose book it is, in the top corner of a cover: the friend's avatar and
/// first name on a dark glass capsule, white like every label on a cover.
struct FriendCoverTag: View {
    let name: String
    let avatar: AccountAvatar
    /// The larger pill a friend's book page sets over its title.
    var isLarge = false

    var body: some View {
        HStack(spacing: isLarge ? 8 : 5) {
            AccountAvatarView(avatar: avatar, firstName: name, size: isLarge ? 32 : 18)
            Text(name)
                .font(isLarge ? .headline : .caption2.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.leading, 4)
        .padding(.trailing, isLarge ? 15 : 9)
        .frame(height: isLarge ? 40 : 26)
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
