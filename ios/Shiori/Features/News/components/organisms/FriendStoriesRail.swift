import SwiftUI

/// The friends at the top of Amis, as stories: a ring lit while one moved since
/// the reader last looked, a tap that narrows the feed to them, and "Inviter"
/// to close the row.
struct FriendStoriesRail: View {
    let stories: [FriendStory]
    let selected: String?
    let onSelect: (String?) -> Void
    let onInvite: () async -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(stories) { story in
                    let isOn = selected == story.id
                    Button { onSelect(isOn ? nil : story.id) } label: {
                        VStack(spacing: 6) {
                            AccountAvatarView(avatar: story.avatar, firstName: story.name, size: 58)
                                .padding(3)
                                .overlay {
                                    Circle().strokeBorder(
                                        story.isNew || isOn ? Color.primary : Color.primary.opacity(0.2),
                                        lineWidth: isOn ? 3 : 2
                                    )
                                }
                            Text(story.name)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                        }
                        .frame(width: 68)
                        .opacity(selected == nil || isOn ? 1 : 0.45)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
                AsyncButton(action: onInvite) {
                    VStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.title3.weight(.medium))
                            .frame(width: 64, height: 64)
                            .overlay {
                                Circle().strokeBorder(.secondary, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                            }
                        Text("Inviter")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.secondary)
                    .frame(width: 68)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("news-invite")
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }
}

#Preview("Stories") {
    FriendStoriesRail(
        stories: NewsFeedLayout.stories(events: FeedEvent.previews, seenAt: .now.addingTimeInterval(-86400)),
        selected: nil,
        onSelect: { _ in },
        onInvite: {}
    )
    .preferredColorScheme(.dark)
}
