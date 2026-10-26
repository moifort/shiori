import SwiftUI

/// What the home screen's carousel puts forward, a page each: what comes out
/// within the week first, then the month's discoveries — or, once the reader
/// took or turned down every one, the page that says the month is done.
enum HomeHeroItem: Identifiable {
    case release(HomeRelease)
    case discovery(Suggestion)
    /// The month's discoveries all taken or turned down, `YYYY-MM`.
    case monthDone(String)

    var id: String {
        switch self {
        case let .release(release): "release-\(release.id)"
        case let .discovery(suggestion): "discovery-\(suggestion.id)"
        case let .monthDone(month): "month-done-\(month)"
        }
    }

    /// How far ahead a release leads the carousel.
    static let releaseWindow = 7

    /// The releases due within the week, the soonest first, then the
    /// discoveries: a date announced to the month or the year is not one the
    /// week can hold. A month whose discoveries ran out closes on its page.
    static func items(
        releases: [HomeRelease],
        discoveries: [Suggestion],
        doneMonth: String? = nil,
        today: Date = .now
    ) -> [HomeHeroItem] {
        let start = today.formatted(.iso8601.year().month().day())
        let end = Calendar.current.date(byAdding: .day, value: releaseWindow, to: today)?
            .formatted(.iso8601.year().month().day()) ?? start
        let soon = releases
            .filter { release in
                guard let date = release.date, date.count == 10 else { return false }
                return date >= start && date <= end
            }
            .sorted { ($0.date ?? "", $0.name) < ($1.date ?? "", $1.name) }
        let done = discoveries.isEmpty ? doneMonth.map { [HomeHeroItem.monthDone($0)] } ?? [] : []
        return soon.map(HomeHeroItem.release) + discoveries.map(HomeHeroItem.discovery) + done
    }
}

/// The top of the home screen on a phone, as the TV app opens: what comes out
/// this week, then the month's discoveries, one page each, swiped sideways,
/// every page over its own cover's colours — the cover, what it is, the way to
/// it on Liquid Glass and, for a discovery, the "+" that adds or awaits it and
/// the thumb that turns it down — with the dots that say where the reader stands. Its colours run up under
/// the bars, and it stops short enough for the rows to show under it.
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
    /// Découvrir, from the page that says the month is done.
    var onShowDiscover: () -> Void = {}
    /// The cover whose colours the month's last page takes: the library's,
    /// as the wait on the selection does.
    var backdropCover: URL?
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

    /// How tall the carousel stands: room for three lines of why.
    static let height: CGFloat = 508
    /// How far each backdrop runs up past its page, under the bars and the
    /// status bar.
    private static let backdropRise: CGFloat = 400
    /// How tall the fade into the page is: long and eased, so the colours
    /// melt into it rather than stop at a line.
    private static let fadeHeight: CGFloat = 240
    /// The thumb's button once a discovery is turned down.
    private static let turnedDownRed = Color(red: 0.78, green: 0.2, blue: 0.2)

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(items) { item in
                    Group {
                        switch item {
                        case let .release(release): releasePage(release)
                        case let .discovery(suggestion): discoveryPage(suggestion)
                        case let .monthDone(month): monthDonePage(month)
                        }
                    }
                    .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $current)
        // The backdrops run up under the bars, past the pager's frame.
        .scrollClipDisabled()
        .frame(height: Self.height)
        .overlay(alignment: .bottom) {
            if items.count > 1 {
                PageDots(count: items.count, index: currentIndex)
                    .padding(.bottom, 12)
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

    /// A volume or an edition due this week, its day in the badge as the TV
    /// app announces a new season.
    private func releasePage(_ release: HomeRelease) -> some View {
        let tile = HomePage.releaseTile(release)
        return page(
            cover: tile,
            badge: release.date.map(Self.releaseBadge) ?? String(localized: "Bientôt"),
            title: tile.title,
            meta: [tile.authorLine, tile.series?.volume.map { String(localized: "Tome \($0)") }]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " · "),
            reason: tile.series?.name,
            onOpen: { onOpenRelease(release) }
        ) {
            Button { onOpenRelease(release) } label: {
                Label("Voir la sortie", systemImage: "calendar")
                    .font(.headline)
                    .frame(width: 200)
            }
            .buttonStyle(.glassProminent)
            .tint(.white)
            .foregroundStyle(.black)
            .controlSize(.extraLarge)
        }
    }

    /// "Sortie aujourd'hui", "Sortie demain", "Sortie le 28 octobre".
    private static func releaseBadge(_ date: String) -> String {
        let today = Date.now.formatted(.iso8601.year().month().day())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now)?
            .formatted(.iso8601.year().month().day())
        if date == today { return String(localized: "Sortie aujourd'hui") }
        if date == tomorrow { return String(localized: "Sortie demain") }
        guard let day = try? Date(date, strategy: .iso8601.year().month().day()) else {
            return ReleaseDateText.coming(date)
        }
        return String(localized: "Sortie le \(day.formatted(.dateTime.day().month(.wide)))")
    }

    private func discoveryPage(_ suggestion: Suggestion) -> some View {
        let isDismissed = dismissed.contains(suggestion.id)
        return page(
            cover: suggestion.tile,
            badge: String(localized: "Découverte du mois"),
            title: suggestion.title,
            meta: meta(suggestion),
            reason: suggestion.reason,
            onOpen: { onOpen(suggestion) }
        ) {
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    Button { onOpen(suggestion) } label: {
                        Label("Découvrir", systemImage: "sparkles")
                            .font(.headline)
                            .frame(width: 150)
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
                .controlSize(.extraLarge)
            }
        }
    }

    /// The month's discoveries all taken or turned down: where the cover
    /// would stand, the month's stack gone through, a check on its front
    /// cover; what the month was, that it is done, when the next ones come,
    /// and the way to Découvrir, which always has more.
    private func monthDonePage(_ month: String) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            DoneStack()
            Text(MonthlyDiscoveries.title(month: month))
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .glassEffect(.clear, in: .capsule)
                .padding(.top, 18)
            Text("Vous avez fait le tour")
                .font(.title.weight(.bold))
                .padding(.top, 10)
            Text(MonthlyDiscoveries.nextArrivalLine(month: month))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.top, 4)
            Button(action: onShowDiscover) {
                Label("Explorer Découvrir", systemImage: "sparkles")
                    .font(.headline)
                    .frame(width: 220)
            }
            .buttonStyle(.glassProminent)
            .tint(.white)
            .foregroundStyle(.black)
            .controlSize(.extraLarge)
            .padding(.top, 16)
            .accessibilityIdentifier("home-month-done-discover")
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(.white)
        .padding(.horizontal, 28)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.colorScheme, .dark)
        .background {
            CoverBackdrop(url: backdropCover, fadeHeight: Self.fadeHeight)
                .padding(.top, -Self.backdropRise)
                .scaleEffect(1 + pull / (Self.height + Self.backdropRise), anchor: .bottom)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home-month-done")
    }

    /// A page as the TV app draws one: the cover, the badge, the title, what
    /// it is and why, then the buttons, over the cover's colours.
    private func page(
        cover: Book,
        badge: String,
        title: String,
        meta: String,
        reason: String?,
        onOpen: @escaping () -> Void,
        @ViewBuilder buttons: () -> some View
    ) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            Button(action: onOpen) {
                VStack(spacing: 0) {
                    BookCover(book: cover, width: 140, showsFormatBadge: false)
                        // A recording says so in the tag the posters carry,
                        // on a blur of the cover, rather than with headphones.
                        .overlay(alignment: .topTrailing) {
                            if cover.format == .audiobook {
                                OutlinedTag(text: String(localized: "Audio"))
                                    .padding(7)
                            }
                        }
                        .shadow(color: .black.opacity(0.5), radius: 22, y: 14)
                    Text(badge)
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .glassEffect(.clear, in: .capsule)
                        .padding(.top, 18)
                    Text(title)
                        .font(.title.weight(.bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .padding(.top, 10)
                    Text(meta)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                        .padding(.top, 4)
                    if let reason {
                        Text(reason)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.65))
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 6)
                    }
                }
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            buttons()
                .padding(.top, 16)
        }
        .padding(.horizontal, 28)
        // Room for the dots under the buttons.
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.colorScheme, .dark)
        .background {
            CoverBackdrop(url: cover.coverURL, fadeHeight: Self.fadeHeight)
                // Up under the bars and the status bar.
                .padding(.top, -Self.backdropRise)
                // Pulled down, the backdrop grows from its foot as the TV
                // app's artwork does: its top stays above the screen, where
                // the blurred cover turns to other colours — a red band
                // showed through the pull.
                .scaleEffect(1 + pull / (Self.height + Self.backdropRise), anchor: .bottom)
        }
    }

    /// Who wrote it and what it is like, as the TV app says a film's genres.
    private func meta(_ suggestion: Suggestion) -> String {
        ([suggestion.authors.joined(separator: ", "), suggestion.short].filter { !$0.isEmpty })
            .joined(separator: " · ")
    }
}

/// The month's covers gone through, in the cover's room: three glass covers
/// fanned out as the empty shelf draws its stack, a check on the front one.
private struct DoneStack: View {
    var body: some View {
        ZStack {
            cover.rotationEffect(.degrees(-7)).offset(x: -14, y: 4)
            cover.rotationEffect(.degrees(6)).offset(x: 14, y: 6)
            cover
                .overlay {
                    Image(systemName: "checkmark")
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
