import SwiftUI

/// The authors as round portraits in a rail, as the TV app lines up a cast:
/// the face and the name under it, nothing else. Three and a half fit a
/// phone's width, so the rail says it goes on.
struct AuthorPortraitRail: View {
    let authors: [FollowedAuthor]
    let onOpen: (FollowedAuthor) -> Void

    static let portraitSize: CGFloat = 93

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 16) {
                ForEach(authors) { author in
                    Button { onOpen(author) } label: {
                        VStack(spacing: 8) {
                            AuthorAvatar(initials: author.initials, portraitURL: author.portraitURL, size: Self.portraitSize)
                            Text(author.name)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .frame(width: Self.portraitSize)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, 20)
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollClipDisabled()
    }
}

#Preview {
    AuthorPortraitRail(authors: FollowedAuthor.previews) { _ in }
        .background(.black)
}
