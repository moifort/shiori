import SwiftUI

/// Everything the Découvrir page can ask for.
enum NewsAction {
    /// A card's book, on the page the rest of the app opens it on.
    case open(NewsCard)
    /// "+": the card's book onto the wish list.
    case wish(NewsCard)
    /// "Pas intéressé" on a discovery or a prize.
    case dismiss(NewsCard)
    /// Everything announced, from "Sorties et découvertes ›".
    case openUpcoming
    /// Découvrir in full, from "Prix littéraires ›".
    case openDiscover
    case invite
    case openAlerts
    case refresh
}

/// The Découvrir tab, pure. The latest news first, as stories filling the
/// screen, one cover each; then the friends' books and the releases and
/// discoveries as walls of large covers; then the prizes as a carousel whose
/// cover tints the band. The cover carries the book: no title or author is
/// written under it, only who or what brought it.
struct NewsPage: View {
    let layout: NewsDiscoverLayout
    /// The cards' books just wished for, by `NewsCard.key`.
    var wished: Set<String> = []
    let isLoading: Bool
    let errorMessage: String?
    let alertsSilenced: Bool
    let onAction: (NewsAction) async -> Void

    private func act(_ action: NewsAction) {
        Task { await onAction(action) }
    }

    var body: some View {
        content
            .navigationTitle("Découvrir")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbarBackground(.hidden, for: .navigationBar)
            // The title sits on the first story's cover colours, white in
            // either appearance, as the home's hero carries it.
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    DiscoverAlertsButton(isSilenced: alertsSilenced) { act(.openAlerts) }
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if let errorMessage, layout.isEmpty, !isLoading {
            EmptyState.failure("Découvrir indisponible", message: errorMessage) {
                await onAction(.refresh)
            }
        } else if isLoading, layout.isEmpty {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if layout.isEmpty {
            EmptyState(
                systemImage: "sparkles",
                title: "Rien de neuf pour l'instant",
                message: "Cette page se remplit toute seule à partir de votre bibliothèque et de vos amis."
            )
            .accessibilityIdentifier("news-empty")
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !layout.today.isEmpty {
                        NewsTodayStories(cards: layout.today, wished: wished, onAction: onAction)
                    }
                    friends
                    if !layout.releases.isEmpty {
                        NewsCoverWall(
                            title: "Sorties et découvertes",
                            cards: layout.releases,
                            wished: wished,
                            onOpenAll: { act(.openUpcoming) },
                            onAction: onAction
                        )
                    }
                    if !layout.awards.isEmpty {
                        NewsAwardsCarousel(cards: layout.awards, wished: wished, onAction: onAction)
                            .padding(.top, 26)
                    }
                }
                .padding(.bottom, 32)
            }
            .refreshable { await onAction(.refresh) }
        }
    }

    /// The friends' books; with no friend yet, the invitation in their place.
    @ViewBuilder
    private var friends: some View {
        if !layout.friends.isEmpty {
            NewsCoverWall(title: "Vos amis", cards: layout.friends, wished: wished, onAction: onAction)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("Vos amis")
                    .font(.title2.weight(.bold))
                Button {
                    act(.invite)
                } label: {
                    Label("Inviter un ami", systemImage: "person.badge.plus")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .frame(height: 40)
                        .glassEffect(.regular.interactive(), in: .capsule)
                }
                .buttonStyle(.plain)
                Text("Ce que lisent et aiment vos amis s'affichera ici.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 26)
        }
    }
}

// MARK: - Aujourd'hui

/// The latest news as stories, one cover each over its own colours, filling
/// the screen under the title: bars at the top count them, a touch on the
/// right half moves on, a swipe too.
struct NewsTodayStories: View {
    let cards: [NewsCard]
    var wished: Set<String> = []
    let onAction: (NewsAction) async -> Void

    @State private var index = 0

    private var current: NewsCard { cards[min(index, cards.count - 1)] }

    var body: some View {
        TabView(selection: $index) {
            ForEach(Array(cards.enumerated()), id: \.element.id) { offset, card in
                NewsStoryPage(
                    card: card,
                    isWished: wished.contains(card.key),
                    onAction: onAction
                )
                .tag(offset)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .environment(\.colorScheme, .dark)
        .overlay(alignment: .top) { header }
        .frame(height: 330)
        // The cover's colours run up under the title and fade into the page.
        .background(alignment: .bottom) {
            CoverBackdrop(url: current.cover.coverURL, fadeHeight: 44, ground: Color(.systemBackground))
                .frame(height: 1100)
                .animation(.smooth, value: index)
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(cards.indices, id: \.self) { bar in
                    Capsule()
                        .fill(.white.opacity(bar <= index ? 1 : 0.3))
                        .frame(height: 3)
                }
            }
            HStack {
                Text(NewsCardText.when(current))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(index + 1) sur \(cards.count)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
                    .monospacedDigit()
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .accessibilityElement(children: .combine)
    }
}

/// One story: the cover at the home hero's size, and beside it the card's
/// side — the emblem of what brought it, its title, its author, why — then
/// "Ajouter".
private struct NewsStoryPage: View {
    let card: NewsCard
    let isWished: Bool
    let onAction: (NewsAction) async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Button {
                Task { await onAction(.open(card)) }
            } label: {
                HStack(alignment: .top, spacing: 18) {
                    BookCover(book: card.cover, width: 124, showsFormatBadge: false, isBound: true)
                        .shadow(color: .black.opacity(0.5), radius: 16, y: 10)
                    VStack(alignment: .leading, spacing: 0) {
                        NewsCardEmblem(card: card)
                        Text(card.cover.title)
                            .font(.title2.weight(.bold))
                            .lineLimit(3)
                            .minimumScaleFactor(0.8)
                            .padding(.top, 8)
                        Text(card.cover.authors.joined(separator: ", "))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                            .padding(.top, 4)
                        if let reason = NewsCardText.reason(card) {
                            Text(reason)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.72))
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 8)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .foregroundStyle(.white)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            NewsCardButtons(card: card, isWished: isWished, fills: true, onAction: onAction)
        }
        .padding(.horizontal, 20)
        .padding(.top, 54)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// What brought a card, over its title on the story's side: the prize between
/// its laurels — both, when it won two — or the line with its symbol or its
/// friends' faces.
private struct NewsCardEmblem: View {
    let card: NewsCard

    var body: some View {
        if case let .award(winner) = card, !winner.mentions.isEmpty {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    ForEach(winner.mentions.prefix(2), id: \.self) { AwardLaurels(mention: $0, compact: true) }
                }
                AwardLaurels(mention: winner.mentions[0], compact: true)
            }
        } else {
            NewsCardKicker(card: card, style: .fiche)
        }
    }
}

// MARK: - The walls

/// A section of covers three by three, each wearing on its foot who or what
/// brought it, and a "+" in its corner.
struct NewsCoverWall: View {
    let title: LocalizedStringKey
    let cards: [NewsCard]
    var wished: Set<String> = []
    var onOpenAll: (() -> Void)?
    let onAction: (NewsAction) async -> Void

    @State private var width: CGFloat = 353

    private static let spacing: CGFloat = 10
    private var columns: Int { NewsDiscoverLayout.wallColumns }
    private var tileWidth: CGFloat { max(90, (width - Self.spacing * CGFloat(columns - 1)) / CGFloat(columns)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let onOpenAll {
                Button(action: onOpenAll) {
                    HStack(spacing: 6) {
                        Text(title)
                        Image(systemName: "chevron.right")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .font(.title2.weight(.bold))
                }
                .buttonStyle(.plain)
            } else {
                Text(title)
                    .font(.title2.weight(.bold))
            }
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: Self.spacing), count: columns),
                spacing: 12
            ) {
                ForEach(cards) { card in
                    NewsCoverTile(card: card, width: tileWidth, isWished: wished.contains(card.key), onAction: onAction)
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }
}

/// A cover, its foot blurred, who or what brought it there in white under it
/// and the "+" in its top corner.
private struct NewsCoverTile: View {
    let card: NewsCard
    let width: CGFloat
    let isWished: Bool
    let onAction: (NewsAction) async -> Void

    var body: some View {
        Button {
            Task { await onAction(.open(card)) }
        } label: {
            PosterCover(book: card.cover, caption: "", width: width, dimming: 0.05)
                // A poster-shaped image would stretch its tile past its row.
                .frame(width: width, height: width * 1.5)
                .clipShape(.rect(cornerRadius: PosterCover.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(card.cover.title)
        .overlay(alignment: .bottom) {
            NewsCardKicker(card: card, style: .tile)
                .padding(.horizontal, 6)
                .padding(.bottom, 7)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .topTrailing) {
            NewsWishButton(card: card, isWished: isWished, size: 26, onAction: onAction)
                .padding(6)
        }
    }
}

// MARK: - Prix littéraires

/// The prizes as a carousel: the winner in the middle large, its neighbours
/// smaller on either side, the band tinted by the cover in the middle.
struct NewsAwardsCarousel: View {
    let cards: [NewsCard]
    var wished: Set<String> = []
    let onAction: (NewsAction) async -> Void

    @State private var selected: String?

    private var current: NewsCard {
        cards.first { $0.id == selected } ?? cards[0]
    }

    var body: some View {
        VStack(spacing: 14) {
            Button {
                Task { await onAction(.openDiscover) }
            } label: {
                HStack(spacing: 6) {
                    Text("Prix littéraires")
                    Image(systemName: "chevron.right")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
            }
            .buttonStyle(.plain)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .bottom, spacing: 14) {
                    ForEach(cards) { card in
                        Button {
                            Task { await onAction(.open(card)) }
                        } label: {
                            BookCover(book: card.cover, width: 150, showsFormatBadge: false, isBound: true)
                                .shadow(color: .black.opacity(0.5), radius: 20, y: 12)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(card.cover.title)
                        .scrollTransition(axis: .horizontal) { view, phase in
                            view.scaleEffect(phase.isIdentity ? 1 : 0.72, anchor: .bottom)
                                .opacity(phase.isIdentity ? 1 : 0.85)
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, 121, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $selected)
            .frame(height: 235)
            NewsCardKicker(card: current, style: .story)
            NewsCardButtons(card: current, isWished: wished.contains(current.key), onAction: onAction)
            if cards.count > 1 {
                HStack(spacing: 7) {
                    ForEach(cards) { card in
                        Capsule()
                            .fill(.white.opacity(card.id == current.id ? 1 : 0.35))
                            .frame(width: card.id == current.id ? 22 : 7, height: 7)
                    }
                }
                .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 22)
        .background {
            CoverBackdrop(url: current.cover.coverURL, fadeHeight: 90, ground: Color(.systemBackground))
                .mask {
                    LinearGradient(
                        stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.18)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .animation(.smooth, value: current.id)
        }
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - The parts every card shares

/// "Ajouter" in white, and the thumb of "Pas intéressé" where the server
/// keeps one.
private struct NewsCardButtons: View {
    let card: NewsCard
    let isWished: Bool
    /// "Ajouter" takes the width the thumb leaves, under a story's side.
    var fills = false
    let onAction: (NewsAction) async -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button {
                Task { await onAction(.wish(card)) }
            } label: {
                Label(isWished ? "Dans vos envies" : "Ajouter", systemImage: isWished ? "checkmark" : "plus")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.black)
                    .frame(width: fills ? nil : 210, height: 46)
                    .frame(maxWidth: fills ? .infinity : nil)
                    .background(.white, in: .capsule)
            }
            .buttonStyle(.plain)
            .disabled(isWished)
            if card.isDismissable {
                Button {
                    Task { await onAction(.dismiss(card)) }
                } label: {
                    Image(systemName: "hand.thumbsdown")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Pas intéressé")
            }
        }
    }
}

/// The "+" on a tile's foot, a tick once the book is wished for.
private struct NewsWishButton: View {
    let card: NewsCard
    let isWished: Bool
    let size: CGFloat
    let onAction: (NewsAction) async -> Void

    var body: some View {
        Button {
            Task { await onAction(.wish(card)) }
        } label: {
            Image(systemName: isWished ? "checkmark" : "plus")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
        .disabled(isWished)
        .accessibilityLabel(isWished ? "Dans vos envies" : "Ajouter à vos envies")
    }
}

/// Who or what brought a card, in white: a friend's face and name, a prize
/// between laurels, a release's day, the month's "comme …".
struct NewsCardKicker: View {
    /// `story`: on glass, under a carousel. `fiche`: bare, over a story's
    /// title, its symbol in a disc. `tile`: on a cover's foot.
    enum Style { case story, fiche, tile }

    let card: NewsCard
    let style: Style

    private var isLong: Bool { style != .tile }

    var body: some View {
        Group {
            switch style {
            case .story:
                content
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 11)
                    .frame(height: 30)
                    .glassEffect(.regular, in: .capsule)
            case .fiche:
                content
                    .font(.footnote.weight(.semibold))
                    .frame(minHeight: 25)
            case .tile:
                content
                    .font(.caption.weight(.semibold))
                    .shadow(color: .black.opacity(0.45), radius: 4)
            }
        }
        .foregroundStyle(.white)
        .lineLimit(1)
    }

    @ViewBuilder
    private var content: some View {
        HStack(spacing: style == .tile ? 4 : 6) {
            switch card {
            case let .friend(move):
                HStack(spacing: -6) {
                    ForEach(([move.lead] + move.others).prefix(style == .fiche ? 3 : 2)) { event in
                        AccountAvatarView(avatar: event.avatar, firstName: event.friendName, size: style == .tile ? 18 : 22)
                    }
                }
                Text(NewsCardText.friend(move, long: isLong))
                if move.lead.kind == .loved {
                    Image(systemName: "heart.fill").font(.caption2)
                }
            case .award:
                Image(systemName: "laurel.leading")
                Text(NewsCardText.label(card, long: isLong))
                Image(systemName: "laurel.trailing")
            default:
                if style == .fiche {
                    Image(systemName: NewsCardText.symbol(card))
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 22, height: 22)
                        .background(.white.opacity(0.16), in: .circle)
                } else {
                    Image(systemName: NewsCardText.symbol(card)).font(.caption2)
                }
                Text(NewsCardText.label(card, long: isLong))
            }
        }
    }
}

/// What a card says of itself, in words.
enum NewsCardText {
    /// The day over a story: "Aujourd'hui", "Hier", "Il y a 3 jours"; "À la
    /// une" for what has no day.
    static func when(_ card: NewsCard, now: Date = .now, calendar: Calendar = .current) -> String {
        guard let date = card.date else { return String(localized: "À la une") }
        let days = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)
        ).day ?? 0
        switch days {
        case ...0: return String(localized: "Aujourd'hui")
        case 1: return String(localized: "Hier")
        default: return String(localized: "Il y a \(days) jours")
        }
    }

    /// "Marc a adoré", "Sophie et Léa ont commencé"; on a tile, the names alone.
    static func friend(_ move: FriendMove, long: Bool) -> String {
        let names = ([move.lead] + move.others).map(\.friendName)
        let who = names.count > 2
            ? String(localized: "\(names[0]) et \(names.count - 1) autres")
            : names.joined(separator: String(localized: " et "))
        guard long else {
            if move.lead.kind == .finished, let rating = move.lead.rating, rating > 0 {
                return "\(who) \(UpcomingRelease.stars(rating))"
            }
            return who
        }
        let plural = names.count > 1
        switch move.lead.kind {
        case .loved: return plural ? String(localized: "\(who) ont adoré") : String(localized: "\(who) a adoré")
        case .finished: return plural ? String(localized: "\(who) ont terminé") : String(localized: "\(who) a terminé")
        case .started: return plural ? String(localized: "\(who) ont commencé") : String(localized: "\(who) a commencé")
        }
    }

    static func symbol(_ card: NewsCard) -> String {
        switch card {
        case let .released(.release(release, _)), let .upcoming(release):
            switch release.source {
            case .saga: "books.vertical.fill"
            case .author: "person.fill"
            case .awaited: "binoculars.fill"
            case .narrator: "mic.fill"
            }
        case .released(.narrator): "mic.fill"
        case .suggestion: "sparkles"
        case .award: "laurel.leading"
        case .friend: "person.2.fill"
        }
    }

    /// The line beside the symbol.
    static func label(_ card: NewsCard, long: Bool, now: Date = .now) -> String {
        switch card {
        case let .released(.release(_, day)):
            let when = dayText(day, now: now)
            return long ? String(localized: "Sorti \(when)") : when
        case let .released(.narrator(news, _)):
            return long ? String(localized: "\(news.narrator) prête sa voix") : news.narrator
        case let .upcoming(release):
            return release.date.map(shortDate) ?? String(localized: "Annoncé")
        case let .suggestion(suggestion):
            return suggestion.short
        case let .award(winner):
            guard let mention = winner.mentions.first else { return "" }
            return long ? "\(mention.award.name) \(mention.year)" : "\(mention.award.stripName) \(mention.year)"
        case let .friend(move):
            return friend(move, long: long)
        }
    }

    /// The sentence under a story's cover, when the card has one to say.
    static func reason(_ card: NewsCard) -> String? {
        switch card {
        case let .suggestion(suggestion): suggestion.reason
        case let .released(.release(release, _)), let .upcoming(release): release.reason.isEmpty ? nil : release.reason
        // Two prizes stand as two emblems over the title; a third is said.
        case let .award(winner): winner.mentions.count > 2 ? winner.awardsLine : nil
        default: nil
        }
    }

    /// "aujourd'hui", "hier", "le 4 nov.".
    private static func dayText(_ day: Date, now: Date, calendar: Calendar = .current) -> String {
        if calendar.isDate(day, inSameDayAs: now) { return String(localized: "aujourd'hui") }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(day, inSameDayAs: yesterday) {
            return String(localized: "hier")
        }
        return day.formatted(.dateTime.day().month(.abbreviated))
    }

    /// "12 déc.", "déc. 2026", "2027", from `YYYY-MM-DD`, `YYYY-MM` or `YYYY`.
    private static func shortDate(_ date: String) -> String {
        let parts = date.split(separator: "-").compactMap { Int($0) }
        let calendar = Calendar.current
        guard let year = parts.first else { return date }
        guard parts.count > 1, let day = calendar.date(from: DateComponents(
            year: year, month: parts[1], day: parts.count > 2 ? parts[2] : 1
        )) else { return String(year) }
        return parts.count > 2
            ? day.formatted(.dateTime.day().month(.abbreviated))
            : day.formatted(.dateTime.month(.abbreviated).year())
    }
}

// MARK: - Previews

private struct NewsPagePreview: View {
    var events: [FeedEvent] = FeedEvent.previews + FeedEvent.sameStartPreviews
    var released = true
    var isLoading = false
    var errorMessage: String?
    var empty = false

    private var layout: NewsDiscoverLayout {
        guard !empty else { return NewsDiscoverLayout(today: [], friends: [], releases: [], awards: []) }
        return NewsDiscoverLayout(
            released: NewsFeedLayout.released(
                releases: released ? UpcomingRelease.releasedPreviews : [],
                narrator: released ? [.preview] : [],
                format: nil
            ),
            events: events,
            upcoming: ReleaseCalendar(releases: UpcomingRelease.previews, now: .now).dated,
            suggestions: MonthlyDiscoveries.preview.suggestions,
            awards: AwardSection.previews
        )
    }

    var body: some View {
        NavigationStack {
            NewsPage(
                layout: layout,
                isLoading: isLoading,
                errorMessage: errorMessage,
                alertsSilenced: false,
                onAction: { _ in }
            )
        }
        .preferredColorScheme(.dark)
    }
}

#Preview("Découvrir") { NewsPagePreview() }
#Preview("Sans amis") { NewsPagePreview(events: []) }
#Preview("Vide") { NewsPagePreview(empty: true) }
#Preview("Loading") { NewsPagePreview(isLoading: true, empty: true) }
#Preview("Failed") { NewsPagePreview(errorMessage: "Le réseau est indisponible.", empty: true) }
