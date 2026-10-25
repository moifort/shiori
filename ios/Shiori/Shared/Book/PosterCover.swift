import SwiftUI

/// A cover as the TV app sets a poster on its shelves: dimmed a little, a
/// thin light rim inside the edge, the cover melting into a blur at its foot
/// where a short line sits in white, and a recording's "Audio" in an outlined
/// tag in the top corner rather than headphones. The home's pile and a book's
/// saga draw their covers with it.
struct PosterCover: View {
    let book: Book
    /// The line inside the foot: how long on the pile, "Tome 3".
    let caption: String
    var width: CGFloat = 102
    /// "Audio" in the corner of a recording. Off where the context already
    /// says it: a saga's volumes under a recording's own page.
    var showsAudioTag = true

    static let cornerRadius: CGFloat = 8

    var body: some View {
        BookCover(book: book, width: width, showsFormatBadge: false, cornerRadius: Self.cornerRadius)
            // Dimmed a little, as the TV app's posters are: a white cover no
            // longer glares beside a dark one.
            .overlay {
                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                    .fill(.black.opacity(0.12))
            }
            .overlay { footBlur }
            .overlay(alignment: .topTrailing) {
                if showsAudioTag, book.format == .audiobook {
                    OutlinedTag(text: String(localized: "Audio"))
                        .padding(6)
                }
            }
            .overlay(alignment: .bottom) {
                Text(caption)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .shadow(color: .black.opacity(0.5), radius: 4)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 9)
            }
            // The thin light rim inside the edge the TV app's posters carry.
            .overlay {
                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.22), lineWidth: 1)
            }
    }

    /// The cover blurred into its foot, more the lower it goes, as the TV
    /// app's tiles melt under their label: the print of a cover never fights
    /// the line, and nothing darkens it.
    private var footBlur: some View {
        // Scaled up before the blur, as CoverBackdrop does, so the edges
        // blur on the cover itself rather than on the transparent corners.
        Color.clear
            .overlay {
                if let url = book.coverURL {
                    CoverImage(url: url) { Color.clear } fallback: { Color.clear }
                        .scaleEffect(1.15)
                        .blur(radius: 10, opaque: true)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                    .fill(.black.opacity(0.12))
            }
            .clipShape(.rect(cornerRadius: Self.cornerRadius, style: .continuous))
            .mask {
                // Eased from the middle of the cover to its foot: a short
                // straight ramp showed where the blur began.
                LinearGradient(
                    stops: (0...10).map { step in
                        let t = Double(step) / 10
                        return .init(color: .black.opacity(t * t * (3 - 2 * t)), location: 0.4 + 0.52 * t)
                    },
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .allowsHitTesting(false)
    }
}

#Preview {
    HStack(spacing: 13) {
        PosterCover(book: .preview, caption: "Tome 1")
        PosterCover(book: .previewFromShelf, caption: "10 jours")
    }
    .padding()
}
