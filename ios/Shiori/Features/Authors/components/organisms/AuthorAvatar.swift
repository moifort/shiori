import SwiftUI

/// An author's face: their portrait once their page has been opened and
/// Wikipedia had one, their initials on a slate disc otherwise — and while
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

    /// The initials in white on a slate disc, as the TV app draws a cast
    /// member it has no photograph of.
    private var monogram: some View {
        Text(initials)
            .font(.system(size: max(13, size / 3.4), weight: .semibold))
            .foregroundStyle(.white.opacity(0.9))
            .frame(width: size, height: size)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.23, green: 0.29, blue: 0.35), Color(red: 0.12, green: 0.16, blue: 0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: .circle
            )
    }
}

extension FollowedAuthor {
    var avatar: AuthorAvatar { AuthorAvatar(initials: initials, portraitURL: portraitURL) }
}

#Preview {
    HStack(spacing: 16) {
        AuthorAvatar(initials: "RH", portraitURL: nil)
        AuthorAvatar(initials: "UG", portraitURL: nil, size: 84)
    }
    .padding()
}
