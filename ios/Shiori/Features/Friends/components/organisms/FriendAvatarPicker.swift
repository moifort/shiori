import SwiftUI

/// The friends as a row of avatars, the way the page is narrowed: nobody
/// picked shows every friend, each avatar tapped picks that friend, tapped
/// again lets them go. Once one is picked, the picked ones wear a white ring
/// and the others fade, so the page says at a glance whose books it shows.
///
/// A friend an invitation just joined arrives with a welcome: their avatar
/// grows into its place, ringed in white, in a burst of confetti.
struct FriendAvatarPicker: View {
    struct Item: Identifiable {
        let id: String
        let name: String
        let avatar: AccountAvatar
    }

    let items: [Item]
    let selected: [String]
    /// The friend just joined, welcomed while it is set.
    var welcomed: String? = nil
    let onToggle: (String) -> Void

    private static let size: CGFloat = 62

    var body: some View {
        ScrollViewReader { reader in
            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(items) { item in
                        avatar(item)
                            .id(item.id)
                            .zIndex(item.id == welcomed ? 1 : 0)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, 20, for: .scrollContent)
            // The confetti fly well past the row.
            .scrollClipDisabled()
            .onChange(of: welcomed, initial: true) { _, id in
                guard let id else { return }
                withAnimation(.smooth) { reader.scrollTo(id, anchor: .center) }
            }
        }
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
                    .modifier(Welcome(isOn: item.id == welcomed))
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

/// A friend's arrival: the avatar grows in past its size and settles, ringed
/// in white with a soft glow, and the confetti burst from behind it.
private struct Welcome: ViewModifier {
    let isOn: Bool

    func body(content: Content) -> some View {
        if isOn {
            content.modifier(Arrival())
        } else {
            content
        }
    }
}

private struct Arrival: ViewModifier {
    @State private var scale: CGFloat = 0.3

    func body(content: Content) -> some View {
        content
            .overlay { Circle().strokeBorder(.white, lineWidth: 3) }
            .shadow(color: .yellow.opacity(0.45), radius: 16)
            .scaleEffect(scale)
            .background { ConfettiBurst().frame(width: 420, height: 420) }
            .task {
                withAnimation(.bouncy(duration: 0.45, extraBounce: 0.15)) { scale = 1.18 }
                try? await Task.sleep(for: .milliseconds(420))
                withAnimation(.smooth(duration: 0.5)) { scale = 1 }
            }
    }
}

#Preview("Nobody picked") {
    FriendAvatarPicker(items: FriendAvatarPicker.previewItems, selected: []) { _ in }
        .preferredColorScheme(.dark)
}

#Preview("A friend just joined") {
    FriendAvatarPicker(items: FriendAvatarPicker.previewItems, selected: [], welcomed: "camille") { _ in }
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
