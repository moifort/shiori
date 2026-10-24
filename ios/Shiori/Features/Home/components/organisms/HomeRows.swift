import SwiftUI

/// The library's figures as one line under the hero — books read, favourites,
/// the pile, pages and hours — the way into the statistics. The line keeps what
/// fits the width, the counts first.
struct HomeFiguresLine: View {
    let readCount: Int
    let favoriteCount: Int
    let toReadCount: Int
    let pagesRead: Int
    let hoursListened: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                ViewThatFits(in: .horizontal) {
                    figures(count: 5)
                    figures(count: 4)
                    figures(count: 3)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Statistiques"))
        .accessibilityIdentifier("home-figures")
    }

    private func figures(count: Int) -> some View {
        HStack(spacing: 14) {
            ForEach(Array(items.prefix(count).enumerated()), id: \.offset) { _, item in
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    if let symbol = item.symbol {
                        Image(systemName: symbol)
                            .font(.caption2)
                            .foregroundStyle(item.tint)
                    }
                    Text(item.value)
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                    Text(item.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .fixedSize()
            }
        }
    }

    private var items: [(symbol: String?, tint: Color, value: String, label: String)] {
        var items: [(String?, Color, String, String)] = [
            ("checkmark", ReadingStatus.read.tint, readCount.formatted(), String(localized: "lus")),
            ("heart.fill", .red, favoriteCount.formatted(), String(localized: "favoris")),
            ("bookmark.fill", ReadingStatus.toRead.tint, toReadCount.formatted(), String(localized: "à lire")),
        ]
        if pagesRead > 0 { items.append((nil, .primary, pagesRead.formatted(), String(localized: "pages"))) }
        if hoursListened > 0 {
            items.append((nil, .primary, String(localized: "\(hoursListened) h"), String(localized: "écoutées")))
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
        var id: String { book.id }
    }

    let items: [Item]
    var coverWidth: CGFloat = 102
    let onOpen: (Book) -> Void

    private static let cornerRadius: CGFloat = 8

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 13) {
                ForEach(items) { item in
                    Button { onOpen(item.book) } label: {
                        BookCover(book: item.book, width: coverWidth, showsFormatBadge: false, cornerRadius: Self.cornerRadius)
                            // Dimmed a little, as the TV app's posters are: a
                            // white cover no longer glares beside a dark one.
                            .overlay {
                                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                                    .fill(.black.opacity(0.12))
                            }
                            .overlay { footBlur(item.book) }
                            // A recording says so in a tag inside the corner,
                            // as the card above it does, not with headphones.
                            .overlay(alignment: .topTrailing) {
                                if item.book.format == .audiobook {
                                    OutlinedTag(text: String(localized: "Audio"))
                                        .padding(6)
                                }
                            }
                            .overlay(alignment: .bottom) {
                                Text(item.caption)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                    .shadow(color: .black.opacity(0.5), radius: 4)
                                    .padding(.horizontal, 6)
                                    .padding(.bottom, 9)
                            }
                            // The thin light rim inside the edge the TV app's
                            // posters carry.
                            .overlay {
                                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                                    .strokeBorder(.white.opacity(0.22), lineWidth: 1)
                            }
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("\(item.book.title), \(item.caption)"))
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("book-tile")
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollClipDisabled()
    }

    /// The cover blurred into its foot, more the lower it goes, as the TV
    /// app's tiles melt under their label: the print of a cover never fights
    /// the line, and nothing darkens it.
    private func footBlur(_ book: Book) -> some View {
        // Scaled up before the blur, as CoverBackdrop does, so the edges
        // blur on the cover itself rather than on the transparent corners.
        Color.clear
            .overlay {
                if let url = book.coverURL {
                    CoverImage(url: url) { Color.clear } fallback: { Color.clear }
                        .scaleEffect(1.15)
                        .blur(radius: 10, opaque: true)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                    .fill(.black.opacity(0.12))
            }
            .clipShape(.rect(cornerRadius: Self.cornerRadius, style: .continuous))
            .mask {
                LinearGradient(
                    stops: [.init(color: .clear, location: 0.55), .init(color: .black, location: 0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .allowsHitTesting(false)
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
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                Text(progressText)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
                ProgressView(value: Double(series.readCount), total: Double(max(series.totalCount, 1)))
                    .tint(.white)
                    .padding(.top, 3)
            }
            .foregroundStyle(.white)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            // At least a card's height, more with larger text.
            .frame(minHeight: 118)
            .background {
                // The cover across the card, held to the card's size: filled,
                // it would otherwise grow the card to its own proportions.
                ZStack {
                    Color(white: 0.15)
                    if let url = series.coverURL {
                        Color.clear.overlay {
                            CoverImage(url: url) { Color.clear } fallback: { Color.clear }
                        }
                        .clipped()
                    }
                    LinearGradient(
                        colors: [.black.opacity(0.05), .black.opacity(0.3), .black.opacity(0.88)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
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
            .clipShape(.rect(cornerRadius: 18))
            .contentShape(.rect(cornerRadius: 18))
            .environment(\.colorScheme, .dark)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private var progressText: String {
        series.isAudio
            ? String(localized: "\(series.readCount) sur \(series.totalCount) écoutés")
            : String(localized: "\(series.readCount) sur \(series.totalCount) lus")
    }
}

#Preview("Figures") {
    HomeFiguresLine(readCount: 83, favoriteCount: 15, toReadCount: 18, pagesRead: 16472, hoursListened: 412) {}
        .padding()
}

#Preview("Lead card") {
    ReadingLeadCard(book: .preview, caption: "depuis 6 j", onOpen: {}, onFinish: {}, onRate: {})
        .padding()
}

#Preview("Cover row") {
    CoverRow(items: Dashboard.preview.reading.map { .init(book: $0, caption: "depuis 3 j") }) { _ in }
        .padding()
}

#Preview("Series card") {
    SeriesShowCard(series: Dashboard.preview.series[0], tag: ("Tome 111 disponible", true)) {}
        .frame(width: 180)
        .padding()
}
