import SwiftUI

/// An author's face: their portrait once their page has been opened and
/// Wikipedia had one, their initials in the accent tint otherwise — and while
/// the portrait loads, so the circle never flashes empty.
struct AuthorAvatar: View {
    let initials: String
    let portraitURL: URL?
    var size: CGFloat = 40

    var body: some View {
        Group {
            if let portraitURL {
                CoverImage(url: portraitURL) { monogram } fallback: { monogram }
            } else {
                monogram
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .accessibilityHidden(true)
    }

    private var monogram: some View {
        Text(initials)
            .font(size > 50 ? .title2.weight(.semibold) : .subheadline.weight(.semibold))
            .foregroundStyle(.tint)
            .frame(width: size, height: size)
            .background(.tint.opacity(0.15), in: .circle)
    }
}

extension FollowedAuthor {
    var avatar: AuthorAvatar { AuthorAvatar(initials: initials, portraitURL: portraitURL) }
}
