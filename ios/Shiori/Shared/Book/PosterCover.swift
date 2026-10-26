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
    /// The line's colour: orange for the day a volume comes out.
    var captionColor: Color = .white
    /// How dark the cover is drawn under its line: a little, as the TV app
    /// dims its posters; more for a volume not out yet.
    var dimming: Double = 0.12
    /// The white bookmark hanging from the top edge: a book being read.
    var marksReading = false
    /// How far a recording got, in percent: a short bar before the line.
    var progress: Int?

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
                if showsAudioTag, book.format == .audiobook {
                    OutlinedTag(text: String(localized: "Audio"))
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
                    Text(caption)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(captionColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
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
    init(book: Book, label: PosterLabel, width: CGFloat = 102, showsAudioTag: Bool = true) {
        self.book = book
        caption = label.caption
        self.width = width
        self.showsAudioTag = showsAudioTag
        dimming = label.dimming
        marksReading = label.marksReading
        progress = label.progress
    }

    init(
        book: Book,
        caption: String,
        width: CGFloat = 102,
        showsAudioTag: Bool = true,
        captionColor: Color = .white,
        dimming: Double = 0.12
    ) {
        self.book = book
        self.caption = caption
        self.width = width
        self.showsAudioTag = showsAudioTag
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

#Preview("Labels") {
    HStack(spacing: 13) {
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
