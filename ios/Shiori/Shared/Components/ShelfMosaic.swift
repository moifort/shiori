import SwiftUI

/// How a shelf of the Library tab is drawn: one row per book, saga or author,
/// with everything the reader said about it, or a mosaic that shows them all
/// at once, as the Photos app shows a library. Remembered per shelf, across
/// launches.
enum ShelfLayout: String {
    case list, mosaic
}

/// The toolbar button that opens a shelf's mosaic, drawn first in the group of
/// its views: the mosaic is one more way of looking at the shelf, lit as they
/// are when it is the one shown.
struct MosaicModeButton: View {
    @Binding var layout: ShelfLayout
    /// What else to set when the mosaic opens — the view it is drawn from.
    var onOpen: () -> Void = {}

    var body: some View {
        Button {
            layout = .mosaic
            onOpen()
        } label: {
            Label("Mosaïque", systemImage: "square.grid.3x3")
        }
        .labelStyle(.iconOnly)
        .tint(layout == .mosaic ? .accentColor : .primary)
    }
}

/// A shelf's mosaic, as the Photos app lays out a library: the tiles edge to
/// edge with a hairline between them, no heading and no caption — the covers
/// say what they are, and a tap says the rest. As many columns as fit at the
/// width a tile aims for, never fewer than three. The tile is told its width.
///
/// `top` and `bottom` take what the list draws around its rows — the failed
/// refresh, the sentinel that asks for the next page.
struct ShelfMosaic<Row: Identifiable, Tile: View, Top: View, Bottom: View>: View {
    let rows: [Row]
    var idealTileWidth: CGFloat = 95
    var spacing: CGFloat = 2
    var margin: CGFloat = 0
    @ViewBuilder let tile: (Row, CGFloat) -> Tile
    @ViewBuilder var top: () -> Top
    @ViewBuilder var bottom: () -> Bottom

    var body: some View {
        GeometryReader { proxy in
            grid(width: proxy.size.width)
        }
    }

    private func grid(width: CGFloat) -> some View {
        let count = max(3, Int((width - 2 * margin + spacing) / (idealTileWidth + spacing)))
        let tileWidth = max(0, (width - 2 * margin - CGFloat(count - 1) * spacing) / CGFloat(count))
        return ScrollView {
            VStack(spacing: 0) {
                top()
                if width > 0 {
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(.fixed(tileWidth), spacing: spacing, alignment: .top),
                            count: count
                        ),
                        spacing: spacing
                    ) {
                        ForEach(rows) { row in tile(row, tileWidth) }
                    }
                    .padding(.horizontal, margin)
                }
                bottom()
            }
        }
    }
}

/// The glyphs the Photos app lays over a thumbnail's foot — the heart of a
/// favourite on the left, what kind of item it is on the right — in white on
/// a shade that keeps them legible over any cover.
struct MosaicGlyphs<Leading: View, Trailing: View>: View {
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 4) {
            leading()
            Spacer(minLength: 0)
            trailing()
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.5), radius: 2)
        .padding(.horizontal, 5)
        .padding(.vertical, 4)
        .background(alignment: .bottom) {
            LinearGradient(colors: [.clear, .black.opacity(0.35)], startPoint: .top, endPoint: .bottom)
                .frame(height: 28)
        }
    }
}
