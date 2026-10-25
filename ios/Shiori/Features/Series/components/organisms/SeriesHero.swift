import SwiftUI

/// The top of a saga's page, as the TV app opens a show: three covers fanned
/// over the colours of the volume to read next, which melt into the page as
/// the book page's do; under them, centred, where the reader stands in small
/// capitals, the saga's name, and its author, who opens their page. Then the
/// page's actions. The ground runs up under the toolbar, whose glass buttons
/// float over it; the text is drawn in the dark appearance whatever the
/// device's, since it sits on a darkened image either way.
struct SeriesHero<Actions: View>: View {
    let name: String
    let author: String
    let state: SeriesState
    /// The volume to read next, in the middle, and the ones on either side
    /// of it, in reading order.
    let fan: SeriesFan
    /// Opens the author's page from their name, a chevron after it. Nil draws
    /// the name alone, as where no volume held carries the author's key.
    var onOpenAuthor: (() -> Void)? = nil
    @ViewBuilder var actions: Actions

    private static var coverWidth: CGFloat { 156 }
    private static var fadeHeight: CGFloat { 320 }
    private static var fadeOverhang: CGFloat { 170 }

    var body: some View {
        VStack(spacing: 0) {
            covers
                .padding(.top, 8)
                .padding(.bottom, 22)
            identity
            actions
                .padding(.top, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .environment(\.colorScheme, .dark)
        .background {
            CoverBackdrop(url: fan.middle?.coverURL, fadeHeight: Self.fadeHeight)
                // Up under the bars, the toolbar's glass floating over it,
                // and on under the first block, which draws over it.
                .padding(.top, -400)
                .padding(.bottom, -Self.fadeOverhang)
        }
    }

    /// The volume to read next upright, the ones around it tilted behind it
    /// and darker, as a hand holds three books.
    private var covers: some View {
        ZStack {
            if let leading = fan.leading {
                tilted(leading, angle: -10, x: -78, darkness: 0.6)
            }
            if let trailing = fan.trailing {
                tilted(trailing, angle: 10, x: 78, darkness: 0.75)
            }
            if let middle = fan.middle {
                cover(middle)
            }
        }
        .frame(height: Self.coverWidth * 1.5)
        .accessibilityHidden(true)
    }

    private func tilted(_ book: Book, angle: Double, x: CGFloat, darkness: Double) -> some View {
        cover(book)
            .colorMultiply(Color(white: darkness))
            .scaleEffect(0.9)
            .offset(x: x, y: 14)
            .rotationEffect(.degrees(angle))
    }

    private func cover(_ book: Book) -> some View {
        BookCover(book: book, width: Self.coverWidth, showsFormatBadge: false)
            .shadow(color: .black.opacity(0.6), radius: 16, y: 18)
    }

    private var identity: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(state.tint)
                    .frame(width: 6, height: 6)
                Text(state.label)
                    .font(.caption2.weight(.bold))
                    .textCase(.uppercase)
                    .tracking(1.1)
                    .foregroundStyle(.white.opacity(0.72))
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("series-state")
            Text(name)
                .font(.largeTitle.weight(.heavy))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .copyable(name)
            authorLine
                .padding(.top, 2)
        }
    }

    /// The author, and the way to their page: a chevron after the name, as a
    /// row's header opens its screen.
    @ViewBuilder private var authorLine: some View {
        let line = Text(author)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .lineLimit(2)
            .multilineTextAlignment(.center)
        if let onOpenAuthor {
            Button(action: onOpenAuthor) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    line
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .accessibilityHidden(true)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Ouvre la fiche de l'auteur"))
            .accessibilityIdentifier("series-author-link")
        } else {
            line.copyable(author)
        }
    }
}

/// The three covers of a saga's hero: the volume to read next in the middle,
/// the one before it and the one after on either side.
struct SeriesFan {
    var leading: Book?
    var middle: Book?
    var trailing: Book?

    /// From the saga's volumes in reading order, centred on `index`: the
    /// neighbours on either side, or the next two past either end, so a saga
    /// begun or nearly done still fans three covers.
    init(volumes: [Book], centredOn index: Int) {
        guard !volumes.isEmpty else { return }
        let centre = min(max(index, 0), volumes.count - 1)
        middle = volumes[centre]
        let before = centre - 1, after = centre + 1
        switch (volumes.indices.contains(before), volumes.indices.contains(after)) {
        case (true, true):
            (leading, trailing) = (volumes[before], volumes[after])
        case (false, true):
            leading = volumes.indices.contains(after + 1) ? volumes[after + 1] : nil
            trailing = volumes[after]
        case (true, false):
            leading = volumes[before]
            trailing = volumes.indices.contains(before - 1) ? volumes[before - 1] : nil
        case (false, false):
            break
        }
    }
}

#Preview {
    let screen = SeriesFixtures.screen
    ScrollView {
        SeriesHero(
            name: screen.series?.name ?? "",
            author: screen.series?.author ?? "",
            state: .inProgress,
            fan: SeriesFan(volumes: screen.owned, centredOn: 1),
            onOpenAuthor: {}
        ) {
            Text(verbatim: "Actions")
        }
    }
    .background(Color(.systemGroupedBackground))
}
