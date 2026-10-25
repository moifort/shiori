import SwiftUI

extension AnyTransition {
    /// A card arriving in one of the home's rows, or leaving it, when a
    /// refresh lands: it grows into its place as the others make room, so the
    /// reader sees what came in.
    static var homeCard: AnyTransition {
        .scale(scale: 0.8).combined(with: .opacity)
    }
}

/// The year's reading as the App Store sets an app's figures under its name:
/// each a figure over what it counts in small capitals, parted by hairlines,
/// with nothing else drawn — no mark, no box, no chevron. The books, pages and
/// hours are this year's, the favourites and the pile the whole shelf's. The
/// whole line is the way into the statistics. Columns that fit the width are
/// spread across it; past that, the line scrolls sideways as the App Store's
/// does.
struct HomeFiguresLine: View {
    let year: Int
    let readCount: Int
    let favoriteCount: Int
    let toReadCount: Int
    let pagesRead: Int
    let hoursListened: Int
    /// Draws the pages even at zero, which the line otherwise leaves out.
    var showsPagesAtZero = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            FiguresLine(items: items)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Statistiques"))
        .accessibilityIdentifier("home-figures")
    }

    private var items: [FiguresLine.Item] {
        // The year as text: a figure would be grouped, "2 026".
        var items = [
            FiguresLine.Item(value: readCount.formatted(), label: String(localized: "lus en \(String(year))")),
            FiguresLine.Item(value: favoriteCount.formatted(), label: String(localized: "favoris")),
            FiguresLine.Item(value: toReadCount.formatted(), label: String(localized: "à lire")),
        ]
        // Pages in thousands — "16k" — so the line stays short.
        if pagesRead > 0 || showsPagesAtZero {
            items.append(FiguresLine.Item(value: FiguresLine.compact(pagesRead), label: String(localized: "pages")))
        }
        if hoursListened > 0 {
            items.append(FiguresLine.Item(value: "\(hoursListened.formatted())h", label: String(localized: "écoutées")))
        }
        return items
    }
}

/// The book read now, at the head of "En cours", as the TV app leads a row with
/// the episode playing: its cover the card's whole height on the leading edge,
/// then over its own colours how long it has been open or how far the
/// recording got, and the next step on Liquid Glass.
struct ReadingLeadCard: View {
    let book: Book
    let caption: String
    let onOpen: () -> Void
    let onFinish: () -> Void
    let onRate: () -> Void

    /// The text's height, which the cover stretches to.
    @State private var textHeight: CGFloat = 0

    private static let coverWidth: CGFloat = 100

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Button(action: onOpen) {
                // Edge to edge, the card's corners rounding it.
                BookCover(
                    book: book,
                    width: Self.coverWidth,
                    showsFormatBadge: false,
                    minHeight: textHeight,
                    cornerRadius: 0
                )
                .overlay(alignment: .topTrailing) {
                    // Inside the corner: overhanging, the card clipped it.
                    if book.format == .audiobook {
                        AudiobookBadge(size: 26).padding(6)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Button(action: onOpen) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(book.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))
                            .lineLimit(1)
                        if let progress = book.listeningProgress {
                            ProgressView(value: Double(progress), total: 100)
                                .tint(.white)
                                .padding(.top, 4)
                        }
                        Text(caption)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home-reading-lead")
                // Both labelled where they fit, the rating as its star alone
                // in a narrow column: a label never breaks over lines.
                ViewThatFits(in: .horizontal) {
                    actions(ratingLabelled: true)
                    actions(ratingLabelled: false)
                }
            }
            .padding(.vertical, 14)
            .padding(.trailing, 12)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { textHeight = $0 }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.colorScheme, .dark)
        .background {
            CoverBackdrop(url: book.coverURL, ground: .clear)
        }
        .clipShape(.rect(cornerRadius: 18))
    }

    private func actions(ratingLabelled: Bool) -> some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                Button(action: onFinish) {
                    Label("Marquer lu", systemImage: "checkmark")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .fixedSize()
                }
                .buttonStyle(.glassProminent)
                .tint(.white)
                .foregroundStyle(.black)
                Button(action: onRate) {
                    Group {
                        if ratingLabelled {
                            Label("Noter", systemImage: "star")
                        } else {
                            Label("Noter", systemImage: "star").labelStyle(.iconOnly)
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .fixedSize()
                }
                .buttonStyle(.glass)
            }
            .controlSize(.small)
        }
        .fixedSize()
    }

    private var subtitle: String {
        guard let volume = book.series?.volume else { return book.authorLine }
        return "\(book.authorLine) · \(String(localized: "Tome \(volume)"))"
    }
}

/// A row of covers that scrolls sideways as the TV app's shelves do: larger,
/// with nothing under them, a short line set inside each cover's foot, where
/// the cover melts into a blur that keeps it readable on any cover.
struct PosterRow: View {
    struct Item: Identifiable {
        let book: Book
        let caption: String
        /// What a tap opens, when it is not the book itself: a release, a
        /// friend's favourite.
        var open: (() -> Void)?
        var id: String { book.id }
    }

    let items: [Item]
    var coverWidth: CGFloat = 102
    let onOpen: (Book) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 13) {
                ForEach(items) { item in
                    Button { item.open?() ?? onOpen(item.book) } label: {
                        PosterCover(book: item.book, caption: item.caption, width: coverWidth)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("\(item.book.title), \(item.caption)"))
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("book-tile")
                    .transition(.homeCard)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollClipDisabled()
    }
}

/// A row of covers that scrolls sideways, each with its title and a line in
/// the colour of what it says — how long open, when added, out or to come.
struct CoverRow: View {
    struct Item: Identifiable {
        let book: Book
        let caption: String
        var captionTint: Color?
        var id: String { book.id }
    }

    let items: [Item]
    var coverWidth: CGFloat = 76
    let onOpen: (Book) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 14) {
                ForEach(items) { item in
                    Button { onOpen(item.book) } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            BookCover(book: item.book, width: coverWidth, formatBadgeSize: 18)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.book.title)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                                Text(item.caption)
                                    .font(.caption2)
                                    .foregroundStyle(item.captionTint.map(AnyShapeStyle.init) ?? AnyShapeStyle(.secondary))
                                    .lineLimit(1)
                            }
                            .frame(width: coverWidth, alignment: .leading)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("book-tile")
                    .transition(.homeCard)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollClipDisabled()
    }
}

/// A tile of "Nouveautés": a volume out or to come, or a book a friend hearted,
/// its cover small over its own colours, the date in green once out and orange
/// while announced.
struct NewsTile: View {
    let book: Book
    let caption: String
    var captionTint: Color?
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 10) {
                BookCover(book: book, width: 34, showsFormatBadge: false, cornerRadius: 4)
                VStack(alignment: .leading, spacing: 1) {
                    Text(book.series.flatMap { series in series.volume.map { "\(series.name) \($0)" } } ?? book.title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(captionTint.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.white.opacity(0.7)))
                }
                .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(6)
            .padding(.trailing, 4)
            .environment(\.colorScheme, .dark)
            .background { CoverBackdrop(url: book.coverURL, ground: .clear) }
            .clipShape(.rect(cornerRadius: 12))
            .contentShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

/// A saga in progress as a card of "Mes séries", as the TV app draws a show
/// under "Up Next": the cover of the volume shelved last across the card, the
/// name, how far the reader is, and the news of it in a tag — a volume out, the
/// next one's date.
struct SeriesShowCard: View {
    let series: Dashboard.SeriesProgress
    /// "Tome 11 disponible", "Tome 6 · 5 nov.": the release of the saga, if any.
    var tag: (text: String, isOut: Bool)?
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 3) {
                Spacer(minLength: 0)
                Text(series.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(progressText)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
                remainingCapsule
                    .padding(.top, 8)
            }
            .foregroundStyle(.white)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            // At least a card's height, more with larger text.
            .frame(minHeight: 176)
            .background { artwork }
            .overlay(alignment: .topLeading) {
                if let tag {
                    Text(tag.text)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .foregroundStyle(tag.isOut ? .black : .white)
                        .glassEffect(tag.isOut ? .regular.tint(.green) : .regular, in: .capsule)
                        .padding(8)
                }
            }
            // A saga heard says so in the corner, as the posters above do.
            .overlay(alignment: .topTrailing) {
                if series.isAudio {
                    OutlinedTag(text: String(localized: "Audio"))
                        .padding(10)
                }
            }
            .clipShape(.rect(cornerRadius: 18))
            // The thin light rim inside the edge, as the posters carry.
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.22), lineWidth: 1)
            }
            .contentShape(.rect(cornerRadius: 18))
            .environment(\.colorScheme, .dark)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    /// The cover across the card, darkened toward its foot and its leading
    /// edge, where the text sits, along an eased curve.
    private var artwork: some View {
        // Held to the card's size: filled, the cover would otherwise grow the
        // card to its own proportions.
        ZStack {
            Color(white: 0.15)
            if let url = series.coverURL {
                Color.clear.overlay {
                    CoverImage(url: url) { Color.clear } fallback: { Color.clear }
                }
                .clipped()
            }
            LinearGradient(
                stops: (0...10).map { step in
                    let t = Double(step) / 10
                    return .init(color: .black.opacity(0.85 * t * t * (3 - 2 * t)), location: 0.1 + 0.9 * t)
                },
                startPoint: .top,
                endPoint: .bottom
            )
            LinearGradient(
                colors: [.black.opacity(0.35), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    /// How far the reader is through the saga, on a white capsule as long as
    /// what it holds: a short bar, then how many volumes are left, "À jour"
    /// once none is.
    private var remainingCapsule: some View {
        HStack(spacing: 10) {
            Capsule()
                .fill(.black.opacity(0.18))
                .frame(width: 72, height: 5)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(.black)
                            .frame(width: proxy.size.width * fraction)
                    }
                }
            Text(remainingText)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .fixedSize()
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.white, in: .capsule)
    }

    private var fraction: CGFloat {
        guard series.totalCount > 0 else { return 0 }
        return CGFloat(min(series.readCount, series.totalCount)) / CGFloat(series.totalCount)
    }

    private var remainingText: String {
        switch max(series.totalCount - series.readCount, 0) {
        case 0: String(localized: "À jour")
        case 1: String(localized: "1 tome")
        case let left: String(localized: "\(left) tomes")
        }
    }

    private var progressText: String {
        series.isAudio
            ? String(localized: "\(series.readCount) sur \(series.totalCount) écoutés")
            : String(localized: "\(series.readCount) sur \(series.totalCount) lus")
    }
}

#Preview("Figures") {
    VStack(spacing: 40) {
        HomeFiguresLine(year: 2026, readCount: 18, favoriteCount: 15, toReadCount: 18, pagesRead: 6320, hoursListened: 0) {}
        HomeFiguresLine(year: 2026, readCount: 18, favoriteCount: 15, toReadCount: 18, pagesRead: 6320, hoursListened: 66) {}
        HomeFiguresLine(year: 2026, readCount: 0, favoriteCount: 0, toReadCount: 1, pagesRead: 0, hoursListened: 0) {}
    }
    .padding()
}

#Preview("Lead card") {
    ReadingLeadCard(book: .preview, caption: "depuis 6j", onOpen: {}, onFinish: {}, onRate: {})
        .padding()
}

#Preview("Cover row") {
    CoverRow(items: Dashboard.preview.reading.map { .init(book: $0, caption: "depuis 3j") }) { _ in }
        .padding()
}

#Preview("Series card") {
    SeriesShowCard(series: Dashboard.preview.series[0], tag: ("Tome 111 disponible", true)) {}
        .frame(width: 180)
        .padding()
}
