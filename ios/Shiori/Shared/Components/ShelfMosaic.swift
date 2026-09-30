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
/// width a tile aims for, never fewer than three, until the reader pinches:
/// spreading two fingers draws fewer, larger covers, closing them more and
/// smaller ones, a column at a time, as Photos zooms its grid. The tile is
/// told its width.
///
/// Given the date each row is shelved on, the month is pinned on a cover's
/// corner in place of the list's headings, one line at most carrying one: on
/// the first cover of a month, or at the head of the next line when the line
/// it starts on already names the month before; and again at the head of a
/// line whenever four have gone by without one, so a long month never scrolls
/// past unnamed.
///
/// `top` and `bottom` take what the list draws around its rows — the failed
/// refresh, the sentinel that asks for the next page.
struct ShelfMosaic<Row: Identifiable, Tile: View, Top: View, Bottom: View>: View {
    let rows: [Row]
    var idealTileWidth: CGFloat = 95
    var spacing: CGFloat = 2
    var margin: CGFloat = 0
    /// How few and how many columns a pinch can reach.
    var zoomRange: ClosedRange<Int> = 2...7
    /// The date a row is shelved on. Nil draws no month tag at all.
    var date: ((Row) -> Date?)? = nil
    @ViewBuilder let tile: (Row, CGFloat) -> Tile
    @ViewBuilder var top: () -> Top
    @ViewBuilder var bottom: () -> Bottom

    /// The columns the reader pinched to. Nil until they do.
    @State private var zoomedColumns: Int?
    /// The magnification at which the last column was added or taken away:
    /// a pinch keeps stepping as long as the fingers keep moving.
    @State private var pinchBase: CGFloat = 1

    var body: some View {
        GeometryReader { proxy in
            grid(width: proxy.size.width)
        }
    }

    private func grid(width: CGFloat) -> some View {
        let fitting = max(3, Int((width - 2 * margin + spacing) / (idealTileWidth + spacing)))
        let count = zoomedColumns ?? fitting
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
                                    if let month = tags[index] {
                                        MosaicDateTag(month: month, isCompact: tileWidth < 80)
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, margin)
                }
                bottom()
            }
        }
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { value in
                    let step = value.magnification / pinchBase
                    guard step > 1.25 || step < 0.8 else { return }
                    let columns = min(max(count + (step > 1 ? -1 : 1), zoomRange.lowerBound), zoomRange.upperBound)
                    pinchBase = value.magnification
                    guard columns != count else { return }
                    withAnimation(.snappy) { zoomedColumns = columns }
                }
                .onEnded { _ in pinchBase = 1 }
        )
    }
}

extension ShelfMosaic {
    /// The most lines that go by without a month tag.
    static var linesPerTag: Int { 4 }

    /// The month each tile that carries a tag names, by its place in the grid.
    func monthTags(columns: Int) -> [Int: Date] {
        guard let date else { return [:] }
        let calendar = Calendar.current
        var tags: [Int: Date] = [:]
        var taggedMonth: DateComponents?
        var lastTaggedLine = Int.min / 2
        for (index, row) in rows.enumerated() {
            let line = index / columns
            guard line != lastTaggedLine, let day = date(row) else { continue }
            let month = calendar.dateComponents([.year, .month], from: day)
            let lineUnnamedTooLong = index % columns == 0 && line - lastTaggedLine >= Self.linesPerTag
            guard month != taggedMonth || lineUnnamedTooLong else { continue }
            tags[index] = day
            taggedMonth = month
            lastTaggedLine = line
        }
        return tags
    }
}

/// Where the reader stands on a book or a saga, in the middle of its cover in
/// the mosaic: the status's own symbol alone, in a small, faint disc of
/// frosted glass with no colour of its own, the cover showing through it — it
/// says the state without shouting over the cover.
struct MosaicStatusBadge: View {
    let symbol: String
    let label: String
    /// The width of the cover it sits on: the disc shrinks with the narrow
    /// covers of a grid pinched tight.
    var coverWidth: CGFloat = .infinity

    private var size: CGFloat { min(28, coverWidth * 0.36) }

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.43, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(.ultraThinMaterial, in: Circle())
            .environment(\.colorScheme, .dark)
            .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1))
            // Faint, so the cover is what the eye lands on.
            .opacity(0.55)
            .accessibilityLabel(Text(label))
    }
}

/// The month pinned on a mosaic tile's top corner, as the Photos app labels
/// its grid: small, in white on a tag of frosted glass with softly rounded
/// corners, which reads over any cover.
struct MosaicDateTag: View {
    let month: Date
    /// Over the narrow covers of a grid pinched tight: the year in two
    /// figures and smaller type, so the tag stays inside its cover — the next
    /// one would cut it.
    var isCompact = false

    var body: some View {
        Text(isCompact
            ? month.formatted(.dateTime.month(.abbreviated).year(.twoDigits))
            : month.formatted(.dateTime.month(.abbreviated).year()))
            .font(isCompact ? .system(size: 9, weight: .semibold) : .caption2.weight(.semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, isCompact ? 4 : 6)
            .padding(.vertical, isCompact ? 2 : 3)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: isCompact ? 4 : 5, style: .continuous))
            .environment(\.colorScheme, .dark)
            .padding(isCompact ? 2 : 4)
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
