import SwiftUI

/// A cover as the TV app sets a poster on its shelves: dimmed a little, a
/// thin light rim inside the edge, the cover melting into a blur at its foot
/// where a short line sits in white, and in the top corner outlined tags for
/// a foreign edition's language and a recording's "Audio", rather than
/// headphones. The home's pile and a book's
/// saga draw their covers with it.
struct PosterCover: View {
    let book: Book
    /// The line inside the foot: how long on the pile, "Tome 3".
    let caption: String
    var width: CGFloat = 102
    /// The language and "Audio" tags in the corner. Off where the context
    /// already says them: a saga's volumes under one edition's own page.
    var showsEditionTags = true
    /// The line's colour: orange for the day a volume comes out.
    var captionColor: Color = .white
    /// How dark the cover is drawn under its line: a little, as the TV app
    /// dims its posters; more for a volume not out yet.
    var dimming: Double = 0.12
    /// The white bookmark hanging from the top edge: a book being read.
    var marksReading = false
    /// How far a recording got, in percent: a short bar before the line.
    var progress: Int?
    /// Stars drawn in place of the line, a half one cut down the middle.
    var rating: Double?

    static let cornerRadius: CGFloat = 8

    var body: some View {
        cover
            // Dimmed a little, as the TV app's posters are: a white cover no
            // longer glares beside a dark one.
            .overlay {
                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                    .fill(.black.opacity(dimming))
            }
            .overlay { footBlur }
            .overlay(alignment: .topTrailing) {
                if showsEditionTags {
                    CoverTags(book: book)
                        .padding(6)
                }
            }
            .overlay(alignment: .topLeading) {
                if marksReading {
                    BookmarkRibbon(width: width < 110 ? 12 : 14)
                        .padding(.leading, width < 110 ? 10 : 12)
                }
            }
            .overlay(alignment: .bottom) {
                HStack(spacing: 6) {
                    if let progress {
                        ProgressBar(fraction: Double(progress) / 100, width: width < 110 ? 30 : 40)
                    }
                    if let rating {
                        PosterStars(rating: rating)
                            .foregroundStyle(captionColor)
                            .accessibilityLabel(caption)
                    } else {
                        Text(caption)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(captionColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
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

    /// A poster with the line and marks the Library tab gives it.
    init(book: Book, label: PosterLabel, width: CGFloat = 102, showsEditionTags: Bool = true) {
        self.book = book
        caption = label.caption
        self.width = width
        self.showsEditionTags = showsEditionTags
        dimming = label.dimming
        marksReading = label.marksReading
        progress = label.progress
        rating = label.rating
    }

    init(
        book: Book,
        caption: String,
        width: CGFloat = 102,
        showsEditionTags: Bool = true,
        captionColor: Color = .white,
        dimming: Double = 0.12
    ) {
        self.book = book
        self.caption = caption
        self.width = width
        self.showsEditionTags = showsEditionTags
        self.captionColor = captionColor
        self.dimming = dimming
    }

    /// The cover as drawn here: without a photo, the typeset stand-in keeps
    /// its title and drops its author line, whose place the caption takes.
    private var cover: some View {
        BookCover(
            book: book,
            width: width,
            showsFormatBadge: false,
            cornerRadius: Self.cornerRadius,
            showsPlaceholderAuthor: false
        )
    }

    /// The cover blurred into its foot, more the lower it goes, as the TV
    /// app's tiles melt under their label: the print of a cover never fights
    /// the line, and nothing darkens it. The cover as drawn, photo or the
    /// typeset stand-in alike: blurring only a photo left the stand-in's
    /// print sharp under "Tome 2".
    private var footBlur: some View {
        // Scaled up before the blur, as CoverBackdrop does, so the edges
        // blur on the cover itself rather than on the transparent corners.
        Color.clear
            .overlay {
                cover
                    .scaleEffect(1.15)
                    .blur(radius: 10, opaque: true)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                    .fill(.black.opacity(dimming))
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

/// A read book's stars in a poster's foot: whole ones filled, and a half one
/// as the left half of a star alone, never the outline of the missing half.
private struct PosterStars: View {
    let rating: Double

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<min(Int(rating.rounded(.down)), 5), id: \.self) { _ in
                Image(systemName: "star.fill")
            }
            if rating - rating.rounded(.down) >= 0.5 {
                LeadingHalf {
                    Image(systemName: "star.fill")
                }
                .clipped()
            }
        }
        .font(.footnote.weight(.semibold))
    }
}

/// Lays its content out at its own size but takes only its left half.
private struct LeadingHalf: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let size = subviews.first?.sizeThatFits(.unspecified) else { return .zero }
        return CGSize(width: size.width / 2, height: size.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, anchor: .topLeading, proposal: .unspecified)
    }
}

#Preview("Labels") {
    HStack(spacing: 13) {
        PosterCover(book: .preview, label: PosterLabel(caption: "★★★½", rating: 3.5))
        PosterCover(book: .preview, label: PosterLabel(caption: "★★★★★", rating: 5))
        PosterCover(book: .preview, label: PosterLabel(caption: "depuis 6j", marksReading: true))
        PosterCover(book: .previewFromShelf, label: PosterLabel(caption: "68%", marksReading: true, progress: 68))
        PosterCover(book: .preview, label: PosterLabel(caption: "Abandonné", dimming: PosterLabel.setAsideDimming))
    }
    .padding()
    .background(.black)
}

#Preview {
    HStack(spacing: 13) {
        PosterCover(book: .preview, caption: "Tome 1")
        PosterCover(book: .previewFromShelf, caption: "10 jours")
        PosterCover(book: Book(id: "3", title: "L'écorchée", authors: ["Donato Carrisi"], status: .toRead), caption: "Tome 2")
    }
    .padding()
}
