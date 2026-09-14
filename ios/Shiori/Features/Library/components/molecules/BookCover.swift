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

    /// Standard trade paperback proportions, so photographed covers are cropped
    /// consistently and placeholders sit at the same size as real ones.
    private var height: CGFloat { width * 1.5 }
    private var cornerRadius: CGFloat { width * 0.07 }

    var body: some View {
        Group {
            if let url = book.coverURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image.resizable().scaledToFill()
                    case .failure:
                        // A cover URL expires after an hour, so a failed load is
                        // far more likely to be an expired link than a missing
                        // book. Falling back beats showing a broken-image glyph.
                        placeholder
                    case .empty:
                        Rectangle().fill(.quaternary)
                    @unknown default:
                        placeholder
                    }
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
