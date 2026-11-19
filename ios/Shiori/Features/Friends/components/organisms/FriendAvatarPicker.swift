import SwiftUI

/// The friends as a row of avatars, the way the page is narrowed: nobody
/// picked shows every friend, each avatar tapped picks that friend, tapped
/// again lets them go. Once one is picked, the picked ones wear a white ring
/// and the others fade, so the page says at a glance whose books it shows.
struct FriendAvatarPicker: View {
    struct Item: Identifiable {
        let id: String
        let name: String
        let avatar: AccountAvatar
    }

    let items: [Item]
    let selected: [String]
    let onToggle: (String) -> Void

    private static let size: CGFloat = 62

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 14) {
                ForEach(items) { item in
                    avatar(item)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, 20, for: .scrollContent)
    }

    private func avatar(_ item: Item) -> some View {
        let isPicked = selected.contains(item.id)
        let isFaded = !selected.isEmpty && !isPicked
        return Button { onToggle(item.id) } label: {
            VStack(spacing: 6) {
                AccountAvatarView(avatar: item.avatar, firstName: item.name, size: Self.size)
                    .opacity(isFaded ? 0.4 : 1)
                    .padding(4)
                    .overlay {
                        Circle().strokeBorder(.white, lineWidth: isPicked ? 2 : 0)
                    }
                Text(item.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isFaded ? .secondary : .primary)
                    .lineLimit(1)
            }
            .frame(width: Self.size + 8)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .animation(.smooth, value: isPicked)
        .animation(.smooth, value: isFaded)
        .accessibilityLabel(Text(item.name))
        .accessibilityAddTraits(isPicked ? .isSelected : [])
    }
}

#Preview("Nobody picked") {
    FriendAvatarPicker(items: FriendAvatarPicker.previewItems, selected: []) { _ in }
        .preferredColorScheme(.dark)
}

#Preview("Two picked") {
    FriendAvatarPicker(items: FriendAvatarPicker.previewItems, selected: ["marc", "sophie"]) { _ in }
        .preferredColorScheme(.dark)
}

extension FriendAvatarPicker {
    static let previewItems: [Item] = [
        Item(id: "marc", name: "Marc", avatar: .hero(.kvothe)),
        Item(id: "sophie", name: "Sophie", avatar: .hero(.alice)),
        Item(id: "lea", name: "Léa", avatar: .hero(.katniss)),
        Item(id: "camille", name: "Camille", avatar: .initials),
    ]
}
