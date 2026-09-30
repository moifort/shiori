import SwiftUI

/// How a shelf of the Library tab is drawn: one row per book, saga or author,
/// with everything the reader said about it, or a mosaic of covers that shows
/// three times as many at once. Remembered per shelf, across launches.
enum ShelfLayout: String {
    case list, mosaic

    var toggled: ShelfLayout { self == .list ? .mosaic : .list }

    /// The layout the button switches to, named by its own symbol.
    var switchSymbol: String { self == .list ? "square.grid.3x3" : "list.bullet" }

    var switchLabel: String {
        self == .list ? String(localized: "Mosaïque") : String(localized: "Liste")
    }
}

/// The toolbar button that switches a shelf between its list and its mosaic.
struct ShelfLayoutButton: View {
    @Binding var layout: ShelfLayout

    var body: some View {
        Button {
            withAnimation(.snappy) { layout = layout.toggled }
        } label: {
            Label(layout.switchLabel, systemImage: layout.switchSymbol)
        }
        .labelStyle(.iconOnly)
        .tint(.primary)
    }
}

/// The mosaic a shelf switches to: its sections, headed as the list heads
/// them, each a grid of tiles at least three across. The tile is told its
/// width, so a cover fills its column whatever the screen.
///
/// `top` and `bottom` take what the list draws around its rows — the failed
/// refresh, the sentinel that asks for the next page.
struct ShelfMosaic<Row: Identifiable, Tile: View, Top: View, Bottom: View>: View {
    let sections: [ListSection<Row>]
    /// The width a tile aims for: the columns are as many as fit, never fewer
    /// than three.
    var idealTileWidth: CGFloat = 105
    @ViewBuilder let tile: (Row, CGFloat) -> Tile
    @ViewBuilder var top: () -> Top
    @ViewBuilder var bottom: () -> Bottom

    private let margin: CGFloat = 16
    private let spacing: CGFloat = 12

    private func columnCount(in width: CGFloat) -> Int {
        max(3, Int((width - 2 * margin + spacing) / (idealTileWidth + spacing)))
    }

    private func tileWidth(in width: CGFloat) -> CGFloat {
        let count = CGFloat(columnCount(in: width))
        return max(0, (width - 2 * margin - (count - 1) * spacing) / count)
    }

    var body: some View {
        GeometryReader { proxy in
            grid(width: proxy.size.width)
        }
    }

    private func grid(width: CGFloat) -> some View {
        let columnCount = columnCount(in: width)
        let tileWidth = tileWidth(in: width)
        return ScrollView {
            VStack(spacing: 0) {
                top()
                if width > 0 {
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(.fixed(tileWidth), spacing: spacing, alignment: .top),
                            count: columnCount
                        ),
                        alignment: .leading,
                        spacing: 20
                    ) {
                        ForEach(sections) { section in
                            Section {
                                ForEach(section.rows) { row in tile(row, tileWidth) }
                            } header: {
                                if !section.title.isEmpty {
                                    Text(section.title)
                                        .font(.headline)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.top, 8)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, margin)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
                bottom()
            }
        }
    }
}

extension ShelfMosaic where Top == EmptyView {
    init(
        sections: [ListSection<Row>],
        idealTileWidth: CGFloat = 105,
        @ViewBuilder tile: @escaping (Row, CGFloat) -> Tile,
        @ViewBuilder bottom: @escaping () -> Bottom
    ) {
        self.init(sections: sections, idealTileWidth: idealTileWidth, tile: tile, top: { EmptyView() }, bottom: bottom)
    }
}

/// The caption under a tile: its name on two lines at most, and a line of
/// detail under it. Left-aligned, as the Books app captions its covers.
struct MosaicCaption<Detail: View>: View {
    let title: String
    @ViewBuilder var detail: () -> Detail

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.weight(.medium))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            detail()
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
