import SwiftUI

/// How a shelf of the Library tab is drawn: one row per book, saga or author,
/// with everything the reader said about it, or a mosaic that shows them all
/// at once, as the Photos app shows a library. The mosaic is what a shelf
/// opens on.
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
/// Given the date each row is shelved on, the month is pinned on a cover's
/// corner in place of the list's headings: on the first cover of every month,
/// and again at the head of a line whenever four have gone by without one, so
/// a long month never scrolls past unnamed.
///
/// `top` and `bottom` take what the list draws around its rows — the failed
/// refresh, the sentinel that asks for the next page.
struct ShelfMosaic<Row: Identifiable, Tile: View, Top: View, Bottom: View>: View {
    let rows: [Row]
    var idealTileWidth: CGFloat = 95
    var spacing: CGFloat = 2
    var margin: CGFloat = 0
    /// The date a row is shelved on. Nil draws no month tag at all.
    var date: ((Row) -> Date?)? = nil
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
        let tags = monthTags(columns: count)
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
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                            tile(row, tileWidth)
                                .overlay(alignment: .topLeading) {
                                    if let tag = tags[index] { MosaicDateTag(text: tag) }
                                }
                        }
                    }
                    .padding(.horizontal, margin)
                }
                bottom()
            }
        }
    }
}

extension ShelfMosaic {
    /// The most lines that go by without a month tag.
    static var linesPerTag: Int { 4 }

    /// The month tag of each tile that carries one, by its place in the grid.
    func monthTags(columns: Int) -> [Int: String] {
        guard let date else { return [:] }
        let calendar = Calendar.current
        var tags: [Int: String] = [:]
        var lastMonth: DateComponents??
        var lastTaggedLine = Int.min / 2
        for (index, row) in rows.enumerated() {
            let day = date(row)
            let month = day.map { calendar.dateComponents([.year, .month], from: $0) }
            let line = index / columns
            let monthChanged = lastMonth.map { $0 != month } ?? true
            let lineUnnamedTooLong = index % columns == 0 && line - lastTaggedLine >= Self.linesPerTag
            lastMonth = .some(month)
            guard let day, monthChanged || lineUnnamedTooLong else { continue }
            tags[index] = day.formatted(.dateTime.month(.abbreviated).year())
            lastTaggedLine = line
        }
        return tags
    }
}

/// Where the reader stands on a book or a saga, in the middle of its cover in
/// the mosaic: the status's own symbol and word, white on its own colour, the
/// one thing a cover cannot say for itself.
struct MosaicStatusPill: View {
    let symbol: String
    let label: String
    let tint: Color

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: symbol).imageScale(.small)
            Text(label)
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(.white)
        .lineLimit(1)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(tint, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.8), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 3)
        .fixedSize()
    }
}

/// The month pinned on a mosaic tile's top corner: small, in white on a dark
/// capsule that reads over any cover.
struct MosaicDateTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.black.opacity(0.6), in: Capsule())
            .padding(4)
            .accessibilityHidden(true)
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
