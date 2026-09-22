import SwiftUI

/// What the reader thinks of something, in one glance: the heart when it is a
/// favourite, the stars otherwise, never both. A hearted book is kept close
/// whatever its score, so the heart says everything the row has room for; the
/// stars only speak for a book the reader judged without keeping.
///
/// Draws nothing when there is neither, so a list stays quiet about books the
/// reader has said nothing about.
struct OpinionMark: View {
    let rating: Int?
    let isFavorite: Bool
    var font: Font = .caption2
    /// The stars are the saga's, lent to an unrated volume: drawn grey.
    var ratingIsInherited: Bool = false

    var body: some View {
        if isFavorite {
            Image(systemName: "heart.fill")
                .font(font)
                .foregroundStyle(.pink)
                .accessibilityLabel(Text("Favori"))
        } else if let rating {
            StarRatingView(rating: rating, font: font, inherited: ratingIsInherited)
        }
    }
}

#Preview {
    VStack(alignment: .trailing, spacing: 12) {
        OpinionMark(rating: 4, isFavorite: true)
        OpinionMark(rating: 4, isFavorite: false)
        OpinionMark(rating: nil, isFavorite: false)
    }
    .padding()
}
