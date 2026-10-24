import SwiftUI

/// What the home screen's carousel puts forward, a page each: what comes out
/// within the week first, then the month's discoveries.
enum HomeHeroItem: Identifiable {
    case release(HomeRelease)
    case discovery(Suggestion)

    var id: String {
        switch self {
        case let .release(release): "release-\(release.id)"
        case let .discovery(suggestion): "discovery-\(suggestion.id)"
        }
    }

    /// How far ahead a release leads the carousel.
    static let releaseWindow = 7

    /// The releases due within the week, the soonest first, then the
    /// discoveries: a date announced to the month or the year is not one the
    /// week can hold.
    static func items(releases: [HomeRelease], discoveries: [Suggestion], today: Date = .now) -> [HomeHeroItem] {
        let start = today.formatted(.iso8601.year().month().day())
        let end = Calendar.current.date(byAdding: .day, value: releaseWindow, to: today)?
            .formatted(.iso8601.year().month().day()) ?? start
        let soon = releases
            .filter { release in
                guard let date = release.date, date.count == 10 else { return false }
                return date >= start && date <= end
            }
            .sorted { ($0.date ?? "", $0.name) < ($1.date ?? "", $1.name) }
        return soon.map(HomeHeroItem.release) + discoveries.map(HomeHeroItem.discovery)
    }
}

/// The top of the home screen on a phone, as the TV app opens: what comes out
/// this week, then the month's discoveries, one page each, swiped sideways,
/// every page over its own cover's colours — the cover, what it is, the way to
/// it on Liquid Glass and, for a discovery, the "+" that adds or awaits it —
/// with the dots that say where the reader stands. It runs up under the bars,
/// which stay empty until the page is scrolled, and stops short enough for the
/// rows to show under it.
struct HomeHeroCarousel: View {
    /// Never empty.
    let items: [HomeHeroItem]
    let onOpenRelease: (HomeRelease) -> Void
    let onOpen: (Suggestion) -> Void
    let onAdd: (Suggestion, ReadingStatus) -> Void
    let onAwait: (Suggestion, ReleaseFormat) -> Void

    @State private var current: HomeHeroItem.ID?
    /// The discoveries just added or awaited from their "+", which turns into
    /// a check to say so before the line moves on.
    @State private var taken: Set<Suggestion.ID> = []

    /// How tall the carousel stands.
    static let height: CGFloat = 490
    /// How far it runs up under the empty bar: the cover starts just under
    /// the status bar, as the TV app's artwork does.
    private static let barOverlap: CGFloat = 50
    /// How tall the fade into the page is: long and eased, so the colours
    /// melt into it rather than stop at a line.
    private static let fadeHeight: CGFloat = 240

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(items) { item in
                    Group {
                        switch item {
                        case let .release(release): releasePage(release)
                        case let .discovery(suggestion): discoveryPage(suggestion)
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
        .padding(.top, -Self.barOverlap)
        .accessibilityIdentifier("home-discovery")
    }

    private func take(_ suggestion: Suggestion) {
        withAnimation(.snappy) { _ = taken.insert(suggestion.id) }
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
        page(
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
                            .frame(width: 170)
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
                    .sensoryFeedback(.success, trigger: taken.contains(suggestion.id))
                    .accessibilityIdentifier("home-discovery-menu")
                }
                .controlSize(.extraLarge)
            }
        }
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
                    BookCover(book: cover, width: 140)
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
                            .lineLimit(2)
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
                .padding(.top, -400)
        }
    }

    /// Who wrote it and what it is like, as the TV app says a film's genres.
    private func meta(_ suggestion: Suggestion) -> String {
        ([suggestion.authors.joined(separator: ", "), suggestion.short].filter { !$0.isEmpty })
            .joined(separator: " · ")
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
            onAwait: { _, _ in }
        )
        Color.clear.frame(height: 600)
    }
    .background(Color(.systemGroupedBackground))
}
