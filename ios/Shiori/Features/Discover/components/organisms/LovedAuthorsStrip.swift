import SwiftUI

/// The Authors shelf's strip: their faces, the name and the friend under each.
struct LovedAuthorsStrip: View {
    let authors: [LovedAuthor]
    let onTapped: (LovedAuthor) -> Void

    private let size: CGFloat = 64

    var body: some View {
        PicksStrip {
            ForEach(authors) { loved in
                Button { onTapped(loved) } label: { avatar(loved) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("discover-friend-author")
            }
        }
    }

    private func avatar(_ loved: LovedAuthor) -> some View {
        VStack(spacing: 4) {
            AuthorAvatar(initials: loved.initials, portraitURL: loved.portraitURL, size: size)
                .overlay(alignment: .topTrailing) {
                    if loved.lovers.lovedByMany {
                        LovedByManyBadge().offset(x: 4, y: -4)
                    }
                }
            Text(loved.name)
                .font(.caption.weight(.medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Text(loved.lovers.caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 84)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(loved.name), \(loved.lovers.caption)")
    }
}

#Preview {
    List {
        LovedAuthorsStrip(authors: FriendPicks.preview.authors) { _ in }
    }
}
