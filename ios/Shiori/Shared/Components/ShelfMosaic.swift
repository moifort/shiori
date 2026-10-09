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
/// width a tile aims for, never fewer than three — or the columns asked for.
/// The tile is told its width.
///
/// Given the date each row is shelved on, the month is pinned on a cover's
/// corner in place of the list's headings, only ever on the first cover of a
/// line and never on two lines closer than three apart: at the head of the
/// first line that opens on a new month, once the last tag is far enough
/// back; and again at the head of a line whenever four have gone by without
/// one, so a long month never scrolls past unnamed. A tag that reaches the foot of the toolbar stays there, over
/// the covers scrolling under it, until the next one comes up and pushes it
/// away, as a list pins its section headings.
///
/// `bottom` takes what the list draws under its rows: the sentinel that asks
/// for the next page.
struct ShelfMosaic<Row: Identifiable, Tile: View, Bottom: View>: View {
    let rows: [Row]
    var idealTileWidth: CGFloat = 95
    var spacing: CGFloat = 2
    var margin: CGFloat = 0
    /// The columns the grid is drawn in. Nil fits as many as the width allows.
    var columns: Int?
    /// A tile's height over its width, which places each line without
    /// measuring it: a cover's 1.5.
    var tileAspect: CGFloat = 1.5
    /// The date a row is shelved on. Nil draws no month tag at all.
    var date: ((Row) -> Date?)? = nil
    @ViewBuilder let tile: (Row, CGFloat) -> Tile
    @ViewBuilder var bottom: () -> Bottom

    /// The month tag held at the foot of the toolbar, and how far the next
    /// one has pushed it up.
    @State private var pinned = PinnedMonth()

    var body: some View {
        GeometryReader { proxy in
            grid(width: proxy.size.width)
        }
    }

    /// The month tags are held at the grid's top, the toolbar's foot.
    private let pinLine: CGFloat = 0

    private func grid(width: CGFloat) -> some View {
        let fitting = max(3, Int((width - 2 * margin + spacing) / (idealTileWidth + spacing)))
        let count = columns ?? fitting
        let tileWidth = max(0, (width - 2 * margin - CGFloat(count - 1) * spacing) / CGFloat(count))
        let tags = monthTags(columns: count)
        let isCompact = tileWidth < 80
        let pitch = tileWidth * tileAspect + spacing
        let taggedIndices = tags.keys.sorted()
        return ScrollView {
            VStack(spacing: 0) {
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
                                    // Gone once it has reached the toolbar's
                                    // foot, where the held tag names it —
                                    // the first line's from the start.
                                    if let month = tags[index], index > pinned.index ?? -1 {
                                        MosaicDateTag(month: month, isCompact: isCompact)
                                    }
                                }
                                // Drawn over the next cover, which the tag
                                // runs onto when it is wider than its own.
                                .zIndex(tags[index] == nil ? 0 : 1)
                        }
                    }
                    .padding(.horizontal, margin)
                }
                bottom()
            }
        }
        // Which tag has reached the pin line, and how close the next one
        // is: worked out from the scroll offset alone, since every line is
        // as tall as the next. Only a change of either redraws the view.
        .onScrollGeometryChange(for: PinnedMonth.self) { geometry in
            // Past the inset of the toolbar the grid scrolls under: 0 at rest.
            PinnedMonth(
                offset: geometry.contentOffset.y + geometry.contentInsets.top, pinLine: pinLine, tagged: taggedIndices,
                columns: count, pitch: pitch, tagHeight: MosaicDateTag.height(isCompact: isCompact)
            )
        } action: { _, new in
            pinned = new
        }
        // At rest the scroll has not moved yet, and says nothing.
        .task(id: [count, rows.count]) {
            pinned = PinnedMonth(
                offset: 0, pinLine: pinLine, tagged: taggedIndices,
                columns: count, pitch: pitch, tagHeight: MosaicDateTag.height(isCompact: isCompact)
            )
        }
        .overlay(alignment: .topLeading) {
            if let index = pinned.index, let month = tags[index] {
                MosaicDateTag(month: month, isCompact: isCompact)
                    .padding(.leading, margin)
                    .offset(y: pinLine + pinned.push)
                    .allowsHitTesting(false)
            }
        }
    }
}

/// The month tag held at the foot of the toolbar: which one, by its place in
/// the grid, and how far the next one has pushed it up.
struct PinnedMonth: Equatable {
    var index: Int?
    var push: CGFloat = 0
}

extension PinnedMonth {
    /// The last tag to have passed the pin line, scrolled by `offset`, and
    /// how far into its height the next one has come. Every line is `pitch`
    /// tall, so where a tag sits follows from its place in the grid. The
    /// first line's tag is held from the start, the grid at rest.
    init(offset: CGFloat, pinLine: CGFloat, tagged: [Int], columns: Int, pitch: CGFloat, tagHeight: CGFloat) {
        let edge = offset + pinLine
        let lineTop = { (index: Int) in CGFloat(index / columns) * pitch }
        let next = tagged.first { lineTop($0) > edge }
        self.index = tagged.last { lineTop($0) <= edge }
        self.push = (next.map { min(0, lineTop($0) - edge - tagHeight) } ?? 0).rounded()
    }
}

extension ShelfMosaic {
    /// The most lines that go by without a month tag.
    static var linesPerTag: Int { 4 }

    /// The fewest lines from one month tag to the next: two tagged lines
    /// always have two bare ones between them.
    static var linesBetweenTags: Int { 3 }

    /// The month each tile that carries a tag names, by its place in the
    /// grid: always the first tile of a line.
    func monthTags(columns: Int) -> [Int: Date] {
        guard let date else { return [:] }
        let calendar = Calendar.current
        var tags: [Int: Date] = [:]
        var taggedMonth: DateComponents?
        var lastTaggedLine = Int.min / 2
        for index in stride(from: 0, to: rows.count, by: columns) {
            let line = index / columns
            guard line - lastTaggedLine >= Self.linesBetweenTags, let day = date(rows[index]) else { continue }
            let month = calendar.dateComponents([.year, .month], from: day)
            let lineUnnamedTooLong = line - lastTaggedLine >= Self.linesPerTag
            guard month != taggedMonth || lineUnnamedTooLong else { continue }
            tags[index] = day
            taggedMonth = month
            lastTaggedLine = line
        }
        return tags
    }
}

/// The month pinned on a mosaic tile's top corner, as the Photos app labels
/// its grid: small, in white on a tag of frosted glass with softly rounded
/// corners, which reads over any cover.
struct MosaicDateTag: View {
    let month: Date
    /// Over the narrow covers of a tight grid: the year in two figures, in
    /// type still large enough to read at a glance.
    var isCompact = false

    /// Its height, padding included: how close the next tag comes before it
    /// pushes this one up.
    static func height(isCompact: Bool) -> CGFloat { isCompact ? 26 : 30 }

    var body: some View {
        Text(isCompact
            ? month.formatted(.dateTime.month(.abbreviated).year(.twoDigits))
            : month.formatted(.dateTime.month(.abbreviated).year()))
            .font(isCompact ? .system(size: 13, weight: .bold) : .footnote.weight(.semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, isCompact ? 6 : 7)
            .padding(.vertical, isCompact ? 3 : 4)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: isCompact ? 5 : 6, style: .continuous))
            .environment(\.colorScheme, .dark)
            .padding(isCompact ? 3 : 4)
            .accessibilityHidden(true)
    }
}

/// The glyphs the Photos app lays over a thumbnail's foot — the heart of a
/// favourite on the left, what stands on the right — in white on a shade that
/// keeps them legible over any cover.
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
        // A notch below the text size: at full scale the glyphs covered too
        // much of a cover a third of the screen wide.
        .imageScale(.small)
        // Capped, as Photos caps its own: past this size the glyphs hid the
        // cover they annotate, and the tile's label already says it all aloud.
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
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
