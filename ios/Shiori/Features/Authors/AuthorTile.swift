import SwiftUI

/// One author in the Authors shelf's mosaic, as the Music app shows its
/// artists: the portrait, or the initials, in a circle across the column, the
/// name centred under it and what the reader holds of them beneath — with
/// their heart, else their stars, as the row ranks them.
struct AuthorTile: View {
    let author: FollowedAuthor
    let width: CGFloat

    var body: some View {
        VStack(spacing: 6) {
            AuthorAvatar(initials: author.initials, portraitURL: author.portraitURL, size: width)
            VStack(spacing: 2) {
                Text(author.name)
                    .font(.caption.weight(.medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                HStack(spacing: 4) {
                    mark
                    Text(books)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
        .frame(width: width)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var mark: some View {
        if author.favoriteCount > 0 {
            Image(systemName: "heart.fill")
                .foregroundStyle(.red)
                .accessibilityLabel(Text("Coup de cœur"))
        } else if let rating = author.averageRating {
            Label {
                Text(rating, format: .number.precision(.fractionLength(1)))
            } icon: {
                Image(systemName: "star.fill").foregroundStyle(.yellow)
            }
            .labelStyle(.caption)
        }
    }

    private var books: String {
        author.bookCount == 1
            ? String(localized: "1 livre")
            : String(localized: "\(author.bookCount) livres")
    }
}
