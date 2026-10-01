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
/// width a tile aims for, never fewer than three — or the columns asked for —
/// until the reader pinches: spreading two fingers draws fewer, larger
/// covers, closing them more and smaller ones, a column at a time, the one
/// grid fading into the other as Photos zooms its grid. The tile is told its
/// width.
///
/// Given the date each row is shelved on, the month is pinned on a cover's
/// corner in place of the list's headings, one line at most carrying one: on
/// the first cover of a month, or at the head of the next line when the line
/// it starts on already names the month before; and again at the head of a
/// line whenever four have gone by without one, so a long month never scrolls
/// past unnamed. A tag that reaches the foot of the toolbar stays there, over
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
    /// How few and how many columns a pinch can reach.
    var zoomRange: ClosedRange<Int> = 3...7
    /// The columns the grid opens on. Nil fits as many as the width allows.
    var initialColumns: Int?
    /// A tile's height over its width, which places each line without
    /// measuring it: a cover's 1.5.
    var tileAspect: CGFloat = 1.5
    /// The date a row is shelved on. Nil draws no month tag at all.
    var date: ((Row) -> Date?)? = nil
    @ViewBuilder let tile: (Row, CGFloat) -> Tile
    @ViewBuilder var bottom: () -> Bottom

    /// The columns the reader pinched to. Nil until they do.
    @State private var zoomedColumns: Int?
    /// The magnification at which the last column was added or taken away:
    /// a pinch keeps stepping as long as the fingers keep moving.
    @State private var pinchBase: CGFloat = 1
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
        let count = zoomedColumns ?? initialColumns ?? fitting
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
                        }
                    }
                    .padding(.horizontal, margin)
                    // A grid per zoom: the tiles do not slide to their new
                    // places, the new grid fades in over the old one.
                    .id(count)
                    .transition(.opacity)
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
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { value in
                    let step = value.magnification / pinchBase
                    guard step > 1.25 || step < 0.8 else { return }
                    let columns = min(max(count + (step > 1 ? -1 : 1), zoomRange.lowerBound), zoomRange.upperBound)
                    pinchBase = value.magnification
                    guard columns != count else { return }
                    withAnimation(.easeInOut(duration: 0.25)) { zoomedColumns = columns }
                }
                .onEnded { _ in pinchBase = 1 }
        )
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

/// The month pinned on a mosaic tile's top corner, as the Photos app labels
/// its grid: small, in white on a tag of frosted glass with softly rounded
/// corners, which reads over any cover.
struct MosaicDateTag: View {
    let month: Date
    /// Over the narrow covers of a grid pinched tight: the year in two
    /// figures and smaller type, so the tag stays inside its cover — the next
    /// one would cut it.
    var isCompact = false

    /// Its height, padding included: how close the next tag comes before it
    /// pushes this one up.
    static func height(isCompact: Bool) -> CGFloat { isCompact ? 21 : 30 }

    var body: some View {
        Text(isCompact
            ? month.formatted(.dateTime.month(.abbreviated).year(.twoDigits))
            : month.formatted(.dateTime.month(.abbreviated).year()))
            .font(isCompact ? .system(size: 11, weight: .semibold) : .footnote.weight(.semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, isCompact ? 4 : 7)
            .padding(.vertical, isCompact ? 2 : 4)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: isCompact ? 4 : 6, style: .continuous))
            .environment(\.colorScheme, .dark)
            .padding(isCompact ? 2 : 4)
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
