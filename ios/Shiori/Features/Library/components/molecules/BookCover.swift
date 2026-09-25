import SwiftUI

/// A book cover at a fixed aspect ratio, or a typographic stand-in when there is
/// no photo — a book added by hand or taken from a series catalogue never has one.
///
/// The placeholder is deliberately not a grey rectangle with an icon: a shelf of
/// those is unreadable. Initials plus a hue derived from the title give each book
/// a stable, distinguishable identity at a glance.
struct BookCover: View {
    let book: Book
    var width: CGFloat = 56
    /// A recording carries a headphones pill in the cover's top corner, in every
    /// list and on the book screen alike: nothing else on a cover says it is
    /// listened to rather than read. Off where the corner holds something else.
    var showsFormatBadge: Bool = true
    /// Stretches the cover past its proportions, cropping the photo's sides, so
    /// a list row can bring its bottom level with the text beside it. Never
    /// shorter than the standard height.
    var minHeight: CGFloat?

    /// Standard trade paperback proportions, so photographed covers are cropped
    /// consistently and placeholders sit at the same size as real ones.
    private var height: CGFloat { max(width * 1.5, minHeight ?? 0) }
    private var cornerRadius: CGFloat { width * 0.07 }

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
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
        // Overhanging the corner, as the status badges do: pinned on the cover
        // rather than printed on it.
        .overlay(alignment: .topTrailing) {
            if showsFormatBadge && book.format == .audiobook {
                let size = max(16, width * 0.32)
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
            Text(book.initials)
                .font(.system(size: width * 0.32, weight: .semibold, design: .serif))
                .foregroundStyle(.white)
        }
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

    var body: some View {
        Image(systemName: "headphones")
            .font(.system(size: size * 0.52, weight: .bold))
            .foregroundStyle(Color(.systemBackground))
            .frame(width: size, height: size)
            .background(Color.primary.opacity(0.85), in: Circle())
            .accessibilityLabel(Text("Livre audio"))
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
