import SwiftUI

/// A book cover at a fixed aspect ratio, or a typographic stand-in when there is
/// no photo — a book added by hand or taken from a series catalogue never has one.
///
/// The placeholder is deliberately not a grey rectangle with an icon: a shelf of
/// those is unreadable. It is typeset like a plain cover — the title at the top,
/// the author at the foot, in small print — on a hue derived from the title, so
/// each book can be read and told apart at a glance.
struct BookCover: View {
    let book: Book
    var width: CGFloat = 56
    /// A recording carries a headphones pill in the cover's top corner, in every
    /// list and on the book screen alike: nothing else on a cover says it is
    /// listened to rather than read. Off where the corner holds something else.
    var showsFormatBadge: Bool = true
    /// The headphones pill's diameter. Nil follows the cover's width, which on
    /// a shelf's larger covers draws it too big beside the title under it.
    var formatBadgeSize: CGFloat?
    /// Dims the cover of a volume the reader does not hold. The headphones pill
    /// stays whole: dimmed with it, the cover showed through it.
    var coverOpacity: Double = 1
    /// Stretches the cover past its proportions, cropping the photo's sides, so
    /// a list row can bring its bottom level with the text beside it. Never
    /// shorter than the standard height.
    var minHeight: CGFloat?
    /// Square corners where covers sit edge to edge, as in a mosaic. Nil
    /// rounds them in proportion to the width.
    var cornerRadius: CGFloat?

    /// Standard trade paperback proportions, so photographed covers are cropped
    /// consistently and placeholders sit at the same size as real ones.
    private var height: CGFloat { max(width * 1.5, minHeight ?? 0) }
    private var radius: CGFloat { cornerRadius ?? width * 0.07 }

    var body: some View {
        Group {
            if let url = book.coverURL {
                // Not AsyncImage: a photo's link is re-signed on every answer,
                // and AsyncImage would fetch it again behind a grey frame.
                // An expired link or a publisher cover that has since vanished
                // from Open Library falls back to the placeholder, which beats
                // a broken-image glyph.
                CoverImage(url: url) {
                    Rectangle().fill(.quaternary)
                } fallback: {
                    placeholder
                }
            } else {
                placeholder
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
        .opacity(coverOpacity)
        // Overhanging the corner, as the status badges do: pinned on the cover
        // rather than printed on it.
        .overlay(alignment: .topTrailing) {
            if showsFormatBadge && book.format == .audiobook {
                let size = formatBadgeSize ?? max(16, width * 0.32)
                AudiobookBadge(size: size)
                    .offset(x: size * 0.3, y: -size * 0.3)
            }
        }
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [placeholderTint, placeholderTint.opacity(0.65)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: width * 0.06) {
                Text(book.title)
                    .font(.system(size: titleSize, weight: .semibold, design: .serif))
                    .lineLimit(8)
                    .layoutPriority(1)
                Spacer(minLength: 0)
                if !authorLine.isEmpty {
                    Text(authorLine)
                        .font(.system(size: authorSize, weight: .bold, design: .serif))
                        .lineLimit(2)
                        .shadow(color: .black.opacity(0.3), radius: 1, y: 0.5)
                }
            }
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .padding(.horizontal, width * 0.08)
            .padding(.vertical, width * 0.12)
        }
    }

    private var authorLine: String { book.authors.joined(separator: ", ") }

    /// "Dune" is set large, a longer title smaller: the size shrinks with the
    /// length of the text, and again if its longest word would not fit on one
    /// line. Length alone never takes it below the size "Le Nom du vent" gets,
    /// the smallest still easy to read on a list row: a longer title is cut
    /// short instead. Only a word too long for the line goes a little under, as
    /// a word split in two reads worse than slightly smaller print.
    private var titleSize: CGFloat {
        fittedSize(
            for: book.title, largest: 0.22, smallest: 0.155, longWordFloor: 0.12, shrinkPerLetter: 0.0046
        )
    }

    private var authorSize: CGFloat {
        fittedSize(
            for: authorLine, largest: 0.13, smallest: 0.105, longWordFloor: 0.09, shrinkPerLetter: 0.001
        )
    }

    private func fittedSize(
        for text: String,
        largest: CGFloat,
        smallest: CGFloat,
        longWordFloor: CGFloat,
        shrinkPerLetter: CGFloat
    ) -> CGFloat {
        let byLength = min(largest, max(smallest, largest - shrinkPerLetter * CGFloat(text.count)))
        let longestWord = text.split(separator: " ").map(\.count).max() ?? 1
        // A bold serif letter averages about 0.62 of its point size in width.
        let byWord = width * 0.84 / (CGFloat(longestWord) * 0.62)
        return min(width * byLength, max(byWord, width * longWordFloor))
    }

    /// A hue derived from the title, so the same book always draws the same
    /// colour and two neighbours on a shelf rarely collide.
    private var placeholderTint: Color {
        let hash = book.title.unicodeScalars.reduce(into: UInt64(5381)) { total, scalar in
            total = total &* 33 &+ UInt64(scalar.value)
        }
        return Color(hue: Double(hash % 360) / 360, saturation: 0.45, brightness: 0.55)
    }
}

/// The pill pinned to a recording's cover: a headphones glyph on a neutral
/// disc, monochrome so it sits beside a cover of any colour without competing
/// with it.
struct AudiobookBadge: View {
    var size: CGFloat = 18

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Image(systemName: "headphones")
            .font(.system(size: size * 0.52, weight: .bold))
            .foregroundStyle(Color(.systemBackground))
            .frame(width: size, height: size)
            .background(background, in: Circle())
            .accessibilityLabel(Text("Livre audio"))
    }

    /// Near-black cut too hard against a light page: a grey there. The dark
    /// appearance keeps its light pastille.
    private var background: Color {
        colorScheme == .dark ? Color.primary.opacity(0.85) : Color(.systemGray)
    }
}

#Preview {
    HStack(spacing: 16) {
        BookCover(
            book: Book(id: "1", title: "Le Nom du vent", authors: ["Patrick Rothfuss"], status: .reading)
        )
        BookCover(
            book: Book(id: "2", title: "La Peur du sage", authors: ["Patrick Rothfuss"], status: .toRead),
            width: 90
        )
    }
    .padding()
}
