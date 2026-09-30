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
            .font(monogramFont)
            .foregroundStyle(.tint)
            .frame(width: size, height: size)
            .background(.tint.opacity(0.15), in: .circle)
    }

    /// Grown with the circle past the page header's size, so the initials of a
    /// mosaic's column-wide portrait do not sit lost in the middle of it.
    private var monogramFont: Font {
        if size > 90 { return .system(size: size * 0.3, weight: .semibold) }
        return size > 50 ? .title2.weight(.semibold) : .subheadline.weight(.semibold)
    }
}

extension FollowedAuthor {
    var avatar: AuthorAvatar { AuthorAvatar(initials: initials, portraitURL: portraitURL) }
}
