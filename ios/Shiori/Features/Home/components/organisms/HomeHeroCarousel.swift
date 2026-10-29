import SwiftUI

/// What the home screen's carousel puts forward, a page each: what came out
/// lately, then what comes out within the week, then the month's discoveries —
/// or, once the reader took or turned down every one, the page that says the
/// month is done; or, when nothing on the shelf is rated, the page that asks
/// for a rating, without which no selection is made.
enum HomeHeroItem: Identifiable {
    case release(HomeRelease)
    case discovery(Suggestion)
    /// The month's discoveries all taken or turned down, `YYYY-MM`.
    case monthDone(String)
    /// Nothing on the shelf rated, so no selection made for the month,
    /// `YYYY-MM`.
    case needsRatings(String)

    var id: String {
        switch self {
        case let .release(release): "release-\(release.id)"
        case let .discovery(suggestion): "discovery-\(suggestion.id)"
        case let .monthDone(month): "month-done-\(month)"
        case let .needsRatings(month): "needs-ratings-\(month)"
        }
    }

    /// How far ahead a release leads the carousel.
    static let releaseWindow = 7
    /// How far back a release out stays in the carousel past the month it
    /// came out in: the week, so the turn of a month never drops yesterday's.
    static let recentWindow = 6

    /// What came out first, the newest first: a day this week or this month,
    /// then what is announced for this month without a day. Then what comes
    /// out within the week, the soonest first, then the discoveries. A
    /// release the reader marked seen is left out. A month whose discoveries
    /// ran out closes on its page, as does a month with no selection for want
    /// of a rated book.
    static func items(
        releases: [HomeRelease],
        discoveries: [Suggestion],
        doneMonth: String? = nil,
        needsRatingsMonth: String? = nil,
        seen: Set<HomeRelease.ID> = [],
        today: Date = .now
    ) -> [HomeHeroItem] {
        let month = localMonth(today)
        var out: [(HomeRelease, Int)] = []
        var thisMonth: [HomeRelease] = []
        var coming: [(HomeRelease, Int)] = []
        for release in releases where !seen.contains(release.id) {
            guard let date = release.date else { continue }
            if date.count == 7 {
                if date == month { thisMonth.append(release) }
                continue
            }
            guard let days = daysFromToday(date, today: today) else { continue }
            if days > 0 {
                if days <= releaseWindow { coming.append((release, days)) }
            } else if -days <= recentWindow || date.hasPrefix(month) {
                out.append((release, days))
            }
        }
        let byName = { (a: HomeRelease, b: HomeRelease) in
            a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
        let lined = out.sorted { $0.1 != $1.1 ? $0.1 > $1.1 : byName($0.0, $1.0) }.map(\.0)
            + thisMonth.sorted(by: byName)
            + coming.sorted { $0.1 != $1.1 ? $0.1 < $1.1 : byName($0.0, $1.0) }.map(\.0)
        let done = discoveries.isEmpty
            ? doneMonth.map { [HomeHeroItem.monthDone($0)] }
                ?? needsRatingsMonth.map { [HomeHeroItem.needsRatings($0)] } ?? []
            : []
        return lined.map(HomeHeroItem.release) + discoveries.map(HomeHeroItem.discovery) + done
    }

    /// What a release's badge says, as near as the day allows: "Sortie
    /// aujourd'hui", "Sortie hier", "Sortie avant-hier", "Sortie cette
    /// semaine", "Sortie ce mois-ci", "Sortie demain", "Sortie mardi" —
    /// "mardi prochain" a week ahead, the same day as today.
    static func releaseBadge(_ date: String, today: Date = .now) -> String {
        guard date.count == 10, let days = daysFromToday(date, today: today) else {
            return date == localMonth(today)
                ? String(localized: "Sortie ce mois-ci")
                : String(localized: "Bientôt")
        }
        switch days {
        case 0: return String(localized: "Sortie aujourd'hui")
        case -1: return String(localized: "Sortie hier")
        case -2: return String(localized: "Sortie avant-hier")
        case -recentWindow ... -3: return String(localized: "Sortie cette semaine")
        case ..<0: return String(localized: "Sortie ce mois-ci")
        case 1: return String(localized: "Sortie demain")
        default:
            let weekday = (Calendar.current.date(byAdding: .day, value: days, to: today) ?? today)
                .formatted(.dateTime.weekday(.wide))
            return days < releaseWindow
                ? String(localized: "Sortie \(weekday)")
                : String(localized: "Sortie \(weekday) prochain")
        }
    }

    /// Today's `YYYY-MM` on the phone's calendar, the one the days are told on.
    private static func localMonth(_ today: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month], from: today)
        return String(format: "%04d-%02d", parts.year ?? 2026, parts.month ?? 1)
    }

    /// How many days a `YYYY-MM-DD` lies from today on the phone's calendar:
    /// negative once past.
    static func daysFromToday(_ date: String, today: Date = .now) -> Int? {
        let parts = date.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        let calendar = Calendar.current
        guard let day = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
        else { return nil }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: today), to: day).day
    }
}

/// The top of the home screen on a phone, as the TV app opens: what came
/// out lately and what comes out this week, then the month's discoveries, one
/// page each, swiped sideways, every page over its own cover's colours. A page
/// sets the cover beside what it is — the badge, the title, who wrote it and
/// why, always in full — as the book page does, the way to it on Liquid Glass
/// under both and, for a discovery, the "+" that adds or awaits it and the
/// thumb that turns it down; for a release, the eye that says it was seen.
/// The dots under it say where the reader stands. Its colours run up under the
/// bars, and it stops short enough for the books open now to show under it.
struct HomeHeroCarousel: View {
    /// Never empty.
    let items: [HomeHeroItem]
    let onOpenRelease: (HomeRelease) -> Void
    let onOpen: (Suggestion) -> Void
    let onAdd: (Suggestion, ReadingStatus) -> Void
    let onAwait: (Suggestion, ReleaseFormat) -> Void
    /// "Pas intéressé": the model leaves it out, and the next look skips it.
    let onDismiss: (Suggestion) -> Void
    /// The red thumb pressed again: the reader changed their mind.
    var onReconsider: (Suggestion) -> Void = { _ in }
    /// A release marked seen: the carousel no longer puts it forward.
    var onSeeRelease: (HomeRelease) -> Void = { _ in }
    /// The eye pressed again: the release comes back.
    var onUnseeRelease: (HomeRelease) -> Void = { _ in }
    /// Découvrir, from the page that says the month is done.
    var onShowDiscover: () -> Void = {}
    /// The books read, to rate them, from the page that asks for a rating.
    var onRate: () -> Void = {}
    /// The cover whose colours the month's last page takes: the library's,
    /// as the wait on the selection does.
    var backdropCover: URL?
    /// `YYYY-MM` the discoveries were chosen for, which their badge names.
    var discoveryMonth = MonthlyDiscoveries.month(of: .now)
    /// How far the page is pulled down past its top: the backdrops grow by as
    /// much from their foot, so the pull never uncovers what lies above them.
    var pull: CGFloat = 0

    @State private var current: HomeHeroItem.ID?
    /// The discoveries just added or awaited from their "+", which turns into
    /// a check to say so before the line moves on.
    @State private var taken: Set<Suggestion.ID> = []
    /// The discoveries just turned down, whose thumb turns red to say so:
    /// they leave the line with the ones taken, once the reader leaves the
    /// page. Pressed again, the thumb takes the dismissal back.
    @State private var dismissed: Set<Suggestion.ID> = []
    /// The releases just marked seen, whose eye fills to say so: they leave
    /// the line once the reader leaves the page.
    @State private var seen: Set<HomeRelease.ID> = []
    /// How tall each page's cover and text stand: the page shown sets the
    /// carousel's height, so a why is never cut and the buttons always sit
    /// as close under the cover as the dots under them.
    @State private var topHeights: [HomeHeroItem.ID: CGFloat] = [:]

    /// The cover's width: its height, half as much again, is the room a why
    /// of 25 words — the most the server writes — takes beside it.
    private static let coverWidth: CGFloat = 124
    private static let coverHeight: CGFloat = coverWidth * 1.5
    /// Above the cover, clear of the figures.
    private static let topPadding: CGFloat = 26
    /// Between the cover and the buttons.
    private static let buttonsGap: CGFloat = 22
    /// A large glass button's height.
    private static let buttonsHeight: CGFloat = 50
    /// Under the buttons: the dots, then the room before the rows.
    private static let dotsGap: CGFloat = 22
    private static let bottomPadding: CGFloat = 2
    private static let dotsHeight: CGFloat = 7
    /// How far each backdrop runs up past its page, under the bars and the
    /// status bar.
    private static let backdropRise: CGFloat = 400
    /// How tall the fade into the page is: long and eased, so the colours
    /// melt into it rather than stop at a line.
    private static let fadeHeight: CGFloat = 240
    /// The thumb's button once a discovery is turned down.
    private static let turnedDownRed = Color(red: 0.78, green: 0.2, blue: 0.2)

    /// How tall the carousel stands: the page shown's cover and text, the
    /// buttons and the dots. A short page no longer takes the tallest one's
    /// room, which left a gap between its cover and its buttons.
    private var height: CGFloat {
        let shown = current ?? items.first?.id
        let top = max(Self.coverHeight, shown.flatMap { topHeights[$0] } ?? 0)
        return Self.topPadding + top + Self.buttonsGap + Self.buttonsHeight
            + Self.dotsGap + Self.dotsHeight + Self.bottomPadding
    }

    var body: some View {
        ScrollView(.horizontal) {
            // Not lazy: every page is measured, so its height is known
            // before the reader swipes to it.
            HStack(spacing: 0) {
                ForEach(items) { item in
                    Group {
                        switch item {
                        case let .release(release): releasePage(release, id: item.id)
                        case let .discovery(suggestion): discoveryPage(suggestion, id: item.id)
                        case let .monthDone(month): monthDonePage(month, id: item.id)
                        case let .needsRatings(month): needsRatingsPage(month, id: item.id)
                        }
                    }
                    // As tall as the carousel, which follows the page shown.
                    .containerRelativeFrame(.horizontal)
                    .frame(height: height)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $current)
        // The backdrops run up under the bars, past the pager's frame.
        .scrollClipDisabled()
        .frame(height: height)
        .animation(.snappy, value: height)
        .overlay(alignment: .bottom) {
            if items.count > 1 {
                PageDots(count: items.count, index: currentIndex)
                    .padding(.bottom, Self.bottomPadding)
            }
        }
        .accessibilityIdentifier("home-discovery")
    }

    /// Turns the "+" into a check once the menu has closed: drawn while the
    /// menu folds back into the button, the check went unseen.
    private func take(_ suggestion: Suggestion) {
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.snappy) { _ = taken.insert(suggestion.id) }
        }
    }

    private var currentIndex: Int {
        items.firstIndex { $0.id == current } ?? 0
    }

    // MARK: - Pages

    /// A volume or an edition just out or due this week, how near in the
    /// badge as the TV app announces a new season, and its saga in place of
    /// a why.
    private func releasePage(_ release: HomeRelease, id: HomeHeroItem.ID) -> some View {
        let tile = HomePage.releaseTile(release)
        let isSeen = seen.contains(release.id)
        return page(
            id: id,
            cover: tile,
            badge: release.date.map { HomeHeroItem.releaseBadge($0) } ?? String(localized: "Bientôt"),
            title: tile.title,
            meta: [tile.authorLine, tile.series?.volume.map { String(localized: "Tome \($0)") }]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " · "),
            reason: tile.series?.name,
            onOpen: { onOpenRelease(release) }
        ) {
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    Button { onOpenRelease(release) } label: {
                        Label("Voir la sortie", systemImage: "calendar")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.white)
                    .foregroundStyle(.black)
                    // Seen, the eye fills white; pressed again, the release
                    // comes back. It leaves the line once the reader leaves
                    // the page, as a discovery turned down does.
                    Button {
                        if isSeen {
                            withAnimation(.snappy) { _ = seen.remove(release.id) }
                            onUnseeRelease(release)
                        } else {
                            withAnimation(.snappy) { _ = seen.insert(release.id) }
                            onSeeRelease(release)
                        }
                    } label: {
                        Label(
                            isSeen ? "Vu" : "Marquer comme vu",
                            systemImage: isSeen ? "eye.slash.fill" : "eye.slash"
                        )
                        .labelStyle(.iconOnly)
                        .font(.headline)
                        .foregroundStyle(isSeen ? .black : .white)
                        .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.glass(isSeen ? .regular.tint(.white) : .regular))
                    .buttonBorderShape(.circle)
                    .sensoryFeedback(trigger: isSeen) { _, marked in
                        .impact(weight: marked ? .medium : .light)
                    }
                    .accessibilityIdentifier("home-release-seen")
                }
                .controlSize(.large)
            }
        }
    }

    private func discoveryPage(_ suggestion: Suggestion, id: HomeHeroItem.ID) -> some View {
        let isDismissed = dismissed.contains(suggestion.id)
        return page(
            id: id,
            cover: suggestion.tile,
            badge: MonthlyDiscoveries.badge(month: discoveryMonth),
            title: suggestion.title,
            meta: suggestion.authors.joined(separator: ", "),
            reason: suggestion.reason,
            onOpen: { onOpen(suggestion) }
        ) {
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    Button { onOpen(suggestion) } label: {
                        Label("Découvrir", systemImage: "sparkles")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.white)
                    .foregroundStyle(.black)
                    Menu {
                        SuggestionAddActions(
                            suggestion: suggestion,
                            onAdd: { status in
                                take(suggestion)
                                onAdd(suggestion, status)
                            },
                            onAwait: { format in
                                take(suggestion)
                                onAwait(suggestion, format)
                            }
                        )
                    } label: {
                        Label(
                            taken.contains(suggestion.id) ? "Ajouté" : "Ajouter",
                            systemImage: taken.contains(suggestion.id) ? "checkmark" : "plus"
                        )
                        .labelStyle(.iconOnly)
                        .font(.headline)
                        .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp)))
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .disabled(dismissed.contains(suggestion.id))
                    .sensoryFeedback(.success, trigger: taken.contains(suggestion.id))
                    .accessibilityIdentifier("home-discovery-menu")
                    // Turned down, the thumb fills and presses down as the
                    // button turns red; pressed again, it comes back up as
                    // it was. Never disabled once done: dimmed, the red went
                    // unseen.
                    Button {
                        if isDismissed {
                            withAnimation(.snappy) { _ = dismissed.remove(suggestion.id) }
                            onReconsider(suggestion)
                        } else {
                            withAnimation(.snappy) { _ = dismissed.insert(suggestion.id) }
                            onDismiss(suggestion)
                        }
                    } label: {
                        Label(
                            isDismissed ? "Écarté" : "Pas intéressé",
                            systemImage: isDismissed ? "hand.thumbsdown.fill" : "hand.thumbsdown"
                        )
                        .labelStyle(.iconOnly)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                        // Down when turned down, back up when taken back.
                        .symbolEffect(isDismissed ? .bounce.down.byLayer : .bounce.up.byLayer, value: isDismissed)
                    }
                    .buttonStyle(.glass(isDismissed ? .regular.tint(Self.turnedDownRed) : .regular))
                    .buttonBorderShape(.circle)
                    .disabled(taken.contains(suggestion.id))
                    .sensoryFeedback(trigger: isDismissed) { _, turnedDown in
                        .impact(weight: turnedDown ? .medium : .light)
                    }
                    .accessibilityIdentifier("home-discovery-dismiss")
                }
                .controlSize(.large)
            }
        }
    }

    /// The month's discoveries all taken or turned down: where the cover
    /// would stand, the month's stack gone through, a check on its front
    /// cover; beside it what the month was, that it is done and when the next
    /// ones come; under both, the way to Découvrir, which always has more.
    private func monthDonePage(_ month: String, id: HomeHeroItem.ID) -> some View {
        layout(id: id) {
            // Drawn for the old cover's room, set down to the new one's.
            DoneStack()
                .scaleEffect(0.84)
                .frame(width: Self.coverWidth, height: Self.coverHeight)
        } side: {
            Text(MonthlyDiscoveries.title(month: month))
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .glassEffect(.clear, in: .capsule)
            Text("Vous avez fait le tour")
                .font(.system(.title2, design: .serif, weight: .bold))
                .padding(.top, 10)
            Text(MonthlyDiscoveries.nextArrivalLine(month: month))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
                .padding(.top, 8)
        } buttons: {
            Button(action: onShowDiscover) {
                Label("Explorer Découvrir", systemImage: "sparkles")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(.white)
            .foregroundStyle(.black)
            .controlSize(.large)
            .accessibilityIdentifier("home-month-done-discover")
        }
        .background { pageBackdrop(backdropCover) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home-month-done")
    }

    /// Nothing on the shelf rated, so the month's selection has nothing to go
    /// on: where the cover would stand, a blank one carrying a star; beside
    /// it the month, what the choice needs; under both, the way to the books
    /// read, to rate them.
    private func needsRatingsPage(_ month: String, id: HomeHeroItem.ID) -> some View {
        layout(id: id) {
            DoneStack(symbol: "star.fill")
                .scaleEffect(0.84)
                .frame(width: Self.coverWidth, height: Self.coverHeight)
        } side: {
            Text(MonthlyDiscoveries.title(month: month))
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .glassEffect(.clear, in: .capsule)
            Text("Notez vos lectures")
                .font(.system(.title2, design: .serif, weight: .bold))
                .padding(.top, 10)
            Text("Donnez des étoiles ou un cœur à vos lectures pour recevoir vos livres du mois")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
                // Always in full: the carousel grows to the page's height.
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
        } buttons: {
            Button(action: onRate) {
                Label("Noter mes lectures", systemImage: "star.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(.white)
            .foregroundStyle(.black)
            .controlSize(.large)
            .accessibilityIdentifier("home-needs-ratings-rate")
        }
        .background { pageBackdrop(backdropCover) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home-needs-ratings")
    }

    /// A page as the book page draws its head: the cover, and beside it the
    /// badge, the title, what it is and why, then the buttons under both,
    /// over the cover's colours.
    private func page(
        id: HomeHeroItem.ID,
        cover: Book,
        badge: String,
        title: String,
        meta: String,
        reason: String?,
        onOpen: @escaping () -> Void,
        @ViewBuilder buttons: () -> some View
    ) -> some View {
        layout(id: id) {
            Button(action: onOpen) {
                BookCover(book: cover, width: Self.coverWidth, showsFormatBadge: false, isBound: true)
                    // A recording and a foreign edition say so in the tags
                    // the posters carry, rather than with headphones.
                    .overlay(alignment: .topTrailing) {
                        CoverTags(book: cover)
                            .padding(6)
                    }
                    .shadow(color: .black.opacity(0.5), radius: 18, y: 12)
            }
            .buttonStyle(.plain)
        } side: {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(badge)
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .glassEffect(.clear, in: .capsule)
                    // Set in serif, as Apple Books titles the book it opens.
                    Text(title)
                        .font(.system(.title2, design: .serif, weight: .bold))
                        .lineLimit(3)
                        .minimumScaleFactor(0.8)
                        .padding(.top, 10)
                    if !meta.isEmpty {
                        Text(meta)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(2)
                            .padding(.top, 5)
                    }
                    // Always in full: the carousel grows to the longest.
                    if let reason, !reason.isEmpty {
                        Text(reason)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .lineSpacing(2)
                            .padding(.top, 8)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        } buttons: {
            buttons()
        }
        .background { pageBackdrop(cover.coverURL) }
    }

    /// A page's cover colours, up under the bars and the status bar.
    private func pageBackdrop(_ url: URL?) -> some View {
        CoverBackdrop(url: url, fadeHeight: Self.fadeHeight)
            .padding(.top, -Self.backdropRise)
            // Pulled down, the backdrop grows from its foot as the TV app's
            // artwork does: its top stays above the screen, where the blurred
            // cover turns to other colours — a red band showed through the
            // pull.
            .scaleEffect(1 + pull / (height + Self.backdropRise), anchor: .bottom)
            // Grown, it stays within its page's width: the next page's spread
            // over the one shown, a band of its colours down the right edge.
            .clipShape(PageColumn())
    }

    /// Every page's frame: the cover and its side held at the top, both
    /// measured, the buttons at the foot over the dots.
    private func layout(
        id: HomeHeroItem.ID,
        @ViewBuilder cover: () -> some View,
        @ViewBuilder side: () -> some View,
        @ViewBuilder buttons: () -> some View
    ) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 18) {
                cover()
                VStack(alignment: .leading, spacing: 0) {
                    side()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(.white)
            .onGeometryChange(for: CGFloat.self, of: \.size.height) { topHeights[id] = $0 }
            Spacer(minLength: Self.buttonsGap)
            buttons()
                .frame(height: Self.buttonsHeight)
        }
        .padding(.horizontal, 20)
        .padding(.top, Self.topPadding)
        .padding(.bottom, Self.dotsGap + Self.dotsHeight + Self.bottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .environment(\.colorScheme, .dark)
    }
}

/// A page's width, open above and below: the backdrop it clips still runs
/// up under the bars.
private struct PageColumn: Shape {
    func path(in rect: CGRect) -> Path {
        Path(CGRect(x: rect.minX, y: rect.minY - 10_000, width: rect.width, height: rect.height + 20_000))
    }
}

/// The month's covers gone through, in the cover's room: three glass covers
/// fanned out as the empty shelf draws its stack, a check on the front one —
/// or a star, when the month waits on a rating.
private struct DoneStack: View {
    var symbol = "checkmark"

    var body: some View {
        ZStack {
            cover.rotationEffect(.degrees(-7)).offset(x: -14, y: 4)
            cover.rotationEffect(.degrees(6)).offset(x: 14, y: 6)
            cover
                .overlay {
                    Image(systemName: symbol)
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                }
                .shadow(color: .black.opacity(0.45), radius: 18, y: 12)
        }
        .frame(width: 150, height: 206)
        .accessibilityHidden(true)
    }

    private var cover: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [.white.opacity(0.2), .white.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.white.opacity(0.24), lineWidth: 1)
            }
            .frame(width: 130, height: 192)
    }
}

/// Where the reader stands among a carousel's pages: a dot each, the current
/// one drawn long.
private struct PageDots: View {
    let count: Int
    let index: Int

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { page in
                Capsule()
                    .fill(.white.opacity(page == index ? 0.95 : 0.4))
                    .frame(width: page == index ? 22 : 7, height: 7)
            }
        }
        .animation(.snappy, value: index)
        .accessibilityElement()
        .accessibilityLabel(Text("Page \(index + 1) sur \(count)"))
    }
}

#Preview {
    ScrollView {
        HomeHeroCarousel(
            items: MonthlyDiscoveries.preview.suggestions.map(HomeHeroItem.discovery),
            onOpenRelease: { _ in },
            onOpen: { _ in },
            onAdd: { _, _ in },
            onAwait: { _, _ in },
            onDismiss: { _ in }
        )
        Color.clear.frame(height: 600)
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Month done") {
    ScrollView {
        HomeHeroCarousel(
            items: [.monthDone("2026-10")],
            onOpenRelease: { _ in },
            onOpen: { _ in },
            onAdd: { _, _ in },
            onAwait: { _, _ in },
            onDismiss: { _ in },
            backdropCover: Book.preview.coverURL
        )
        Color.clear.frame(height: 600)
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Needs ratings") {
    ScrollView {
        HomeHeroCarousel(
            items: [.needsRatings("2026-10")],
            onOpenRelease: { _ in },
            onOpen: { _ in },
            onAdd: { _, _ in },
            onAwait: { _, _ in },
            onDismiss: { _ in },
            backdropCover: Book.preview.coverURL
        )
        Color.clear.frame(height: 600)
    }
    .background(Color(.systemGroupedBackground))
}
