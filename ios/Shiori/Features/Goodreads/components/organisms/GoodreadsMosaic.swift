import SwiftUI

/// The head of the Goodreads pages: a tilted wall of the covers the export
/// found, sharp in the middle, melting into a blur under the status bar and
/// under the title at its foot — blurred, never darkened. A book with no
/// cover draws the app's typeset stand-in, so the wall is never a grid of
/// grey boxes.
struct GoodreadsMosaic: View {
    let books: [Book]
    var height: CGFloat = 400

    private static let columns = 8
    private static let rows = 4
    private static let coverWidth: CGFloat = 78

    /// The wall is wider than any phone: it hangs in an overlay of the black
    /// ground, so the page keeps the screen's width rather than the wall's.
    var body: some View {
        Color.black
            .overlay {
                wall
                    .rotationEffect(.degrees(-8))
                    .offset(x: -20, y: -24)
            }
            .overlay {
                // Under the title at the foot, then under the status bar.
                ZStack {
                    blur(clearUntil: 0.3, solidFrom: 0.78)
                    blur(clearUntil: 0.45, solidFrom: 0, height: 130)
                        .scaleEffect(y: -1)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
            }
        .frame(height: height)
        .clipped()
        .accessibilityHidden(true)
    }

    private var wall: some View {
        VStack(spacing: 8) {
            ForEach(0..<Self.rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(0..<Self.columns, id: \.self) { column in
                        if let book = book(row: row, column: column) {
                            BookCover(book: book, width: Self.coverWidth, showsFormatBadge: false)
                        }
                    }
                }
                .offset(x: row.isMultiple(of: 2) ? -40 : 0)
            }
        }
        .fixedSize()
    }

    /// The covers go round the wall as often as it takes to fill it.
    private func book(row: Int, column: Int) -> Book? {
        guard !books.isEmpty else { return nil }
        return books[(row * 5 + column) % books.count]
    }

    /// A blur rising from the bottom of its frame: clear down to `clearUntil`,
    /// whole from `solidFrom`.
    private func blur(clearUntil: Double, solidFrom: Double, height: CGFloat? = nil) -> some View {
        Rectangle()
            .fill(.regularMaterial)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: min(clearUntil, solidFrom)),
                        .init(color: .black, location: max(clearUntil, solidFrom)),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(height: height)
    }
}

#Preview {
    GoodreadsMosaic(books: GoodreadsPreview.preview.rows.map(\.cover))
        .environment(\.colorScheme, .dark)
}
