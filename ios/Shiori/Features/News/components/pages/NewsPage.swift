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

/// The Découvrir tab, pure: an agenda of what the book world brought the
/// reader. At the top "À la une", a rail of the releases of what the reader
/// follows, out lately or soon, mixed with the friends' latest favourites;
/// then a strip of the days that bring something, a month back and a month
/// ahead, each with a dot per piece of news; under it the day picked, its
/// first news as a large card over its cover's colours, the rest as rows;
/// then a shelf per follow — the friends' coups de cœur, the followed series,
/// the favourite authors and narrators, the wish list — each left out when
/// empty; then the year's prizes, one winner a page, left out once each is
/// added or turned down.
struct NewsPage: View {
    let agenda: NewsAgenda
    /// The cards' books just wished for, by `NewsCard.key`.
    var wished: Set<String> = []
    let isLoading: Bool
    let errorMessage: String?
    let alertsSilenced: Bool
    let onAction: (NewsAction) async -> Void

    @State private var picked: Date?

    private func act(_ action: NewsAction) {
        Task { await onAction(action) }
    }

    private var pickedDay: Date? {
        agenda.days.contains { $0.day == picked } ? picked : agenda.openingDay
    }
    private var day: NewsAgendaDay? {
        agenda.days.first { $0.day == pickedDay }
    }

    var body: some View {
        content
            .navigationTitle("Découvrir")
            // The home's bar: the name on the left, the buttons on the right,
            // sent away together by scrolling down.
            .scrollAwayBar(String(localized: "Découvrir")) {
                ScrollBarButton(
                    title: "Notifications",
                    systemImage: alertsSilenced ? "bell.slash" : "bell"
                ) { act(.openAlerts) }
                .accessibilityIdentifier("discover-alerts")
                AccountSettingsButton()
            }
            // The title sits on the day's first cover colours, white in
            // either appearance, as the home's hero carries it.
            .toolbarColorScheme(.dark, for: .navigationBar)
    }

    @ViewBuilder
    private var content: some View {
        if let errorMessage, agenda.isEmpty, !isLoading {
            EmptyState.failure("Découvrir indisponible", message: errorMessage) {
                await onAction(.refresh)
            }
        } else if isLoading, agenda.isEmpty {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if agenda.isEmpty {
            EmptyState(
                systemImage: "sparkles",
                title: "Rien de neuf pour l'instant",
                message: "Cette page se remplit toute seule à partir de votre bibliothèque et de vos amis."
            )
            .accessibilityIdentifier("news-empty")
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        if !agenda.highlights.isEmpty {
                            NewsHighlights(
                                highlights: agenda.highlights,
                                today: agenda.today,
                                opening: agenda.openingHighlight,
                                onAction: onAction
                            )
                            .padding(.bottom, 30)
                        }
                        if let pickedDay {
                            NewsDayStrip(
                                days: agenda.days,
                                today: agenda.today,
                                picked: Binding(get: { pickedDay }, set: { picked = $0 })
                            )
                        }
                        if let day {
                            NewsDaySection(day: day, today: agenda.today, wished: wished, onAction: onAction)
                                .padding(.top, 22)
                        }
                    }
                    .environment(\.colorScheme, .dark)
                    // The first cover's colours run up under the title and
                    // fade into the page.
                    .background(alignment: .top) {
                        CoverBackdrop(
                            url: (agenda.highlights.first { $0.id == agenda.openingHighlight }?.card ?? day?.cards.first)?
                                .cover.coverURL,
                            fadeHeight: 160,
                            ground: Color(.systemBackground)
                        )
                        .frame(height: 760)
                        .offset(y: -300)
                        .animation(.smooth, value: day?.id)
                    }
                    shelves
                    if !prizes.isEmpty {
                        NewsPrizesSlider(cards: prizes, wished: wished, onAction: onAction)
                            .padding(.top, 30)
                    }
                    if !agenda.hasFriends {
                        invitation.padding(.top, 30)
                    }
                }
                .padding(.bottom, 32)
            }
            .refreshable { await onAction(.refresh) }
        }
    }

    /// The winners still to decide on: one added or turned down leaves.
    private var prizes: [NewsCard] {
        agenda.prizes.filter { !wished.contains($0.key) }
    }

    /// A rail per follow, each left out when it holds nothing.
    @ViewBuilder
    private var shelves: some View {
        let shelves = agenda.shelves
        if !shelves.loves.isEmpty {
            NewsLovesRail(moves: shelves.loves, onAction: onAction).padding(.top, 30)
        }
        if !shelves.series.isEmpty {
            NewsSeriesRail(items: shelves.series, onAction: onAction).padding(.top, 30)
        }
        if !shelves.authors.isEmpty {
            NewsPeopleRail(title: "Auteurs préférés", items: shelves.authors, onAction: onAction).padding(.top, 30)
        }
        if !shelves.narrators.isEmpty {
            NewsPeopleRail(title: "Narrateurs préférés", items: shelves.narrators, onAction: onAction).padding(.top, 30)
        }
        if !shelves.wishes.isEmpty {
            NewsWishesRail(items: shelves.wishes, onAction: onAction).padding(.top, 30)
        }
    }

    /// With no friend yet, the invitation in their place.
    private var invitation: some View {
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
    }
}

// MARK: - L'agenda

/// The days that bring something, oldest first, drawn as a release's calendar
/// leaf: the day picked in white, today ringed, a dot under each for its news,
/// the month over the first leaf of each. It scrolls sideways and opens on the
/// day picked.
struct NewsDayStrip: View {
    let days: [NewsAgendaDay]
    let today: Date
    @Binding var picked: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("L'agenda")
                .font(.title2.weight(.bold))
                .padding(.horizontal, 20)
            .foregroundStyle(.white)
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(Self.opensMonth(index, in: days) ? Self.month(day.day) : " ")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(0.6)
                                    .foregroundStyle(.white.opacity(0.6))
                                    .fixedSize()
                                    .frame(width: 45, alignment: .leading)
                                    .accessibilityHidden(true)
                                NewsDayLeaf(
                                    day: day,
                                    isToday: day.day == today,
                                    isPicked: day.day == picked
                                ) { picked = day.day }
                            }
                            .id(day.day)
                        }
                    }
                    .padding(.horizontal, 20)
                    .scrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                .onAppear { proxy.scrollTo(picked, anchor: .center) }
            }
        }
    }

    /// Whether the leaf at `index` is the first of its month.
    static func opensMonth(_ index: Int, in days: [NewsAgendaDay], calendar: Calendar = .current) -> Bool {
        index == 0 || !calendar.isDate(days[index].day, equalTo: days[index - 1].day, toGranularity: .month)
    }

    /// "NOV.", over the month's first leaf.
    static func month(_ day: Date) -> String {
        day.formatted(.dateTime.month(.abbreviated)).localizedUppercase
    }
}

/// One day of the strip: its weekday over its number on a light blur ringed
/// in white, and under it a dot for each piece of news, three at most.
private struct NewsDayLeaf: View {
    let day: NewsAgendaDay
    let isToday: Bool
    let isPicked: Bool
    let onPick: () -> Void

    var body: some View {
        Button(action: onPick) {
            VStack(spacing: 6) {
                VStack(spacing: 1) {
                    Text(day.day.formatted(.dateTime.weekday(.abbreviated)).replacingOccurrences(of: ".", with: "").localizedUppercase)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isPicked ? AnyShapeStyle(.black.opacity(0.6)) : AnyShapeStyle(.white.opacity(0.8)))
                    Text(day.day.formatted(.dateTime.day()))
                        .font(.headline.weight(.bold))
                        .monospacedDigit()
                }
                .foregroundStyle(isPicked ? .black : .white)
                .frame(width: 45, height: 58)
                .background {
                    if isPicked {
                        RoundedRectangle(cornerRadius: 12).fill(.white)
                    } else {
                        RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial).opacity(0.5)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(isPicked ? 0 : isToday ? 1 : 0.34), lineWidth: isToday ? 1.5 : 1)
                }
                HStack(spacing: 3) {
                    ForEach(0..<min(day.cards.count, 3), id: \.self) { _ in
                        Circle().fill(.white).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(day.day.formatted(.dateTime.weekday(.wide).day().month(.wide))))
        .accessibilityValue(Text(NewsDaySection.count(day, isFuture: false)))
        .accessibilityAddTraits(isPicked ? .isSelected : [])
    }
}

// MARK: - Le jour

/// The day picked: its name and how much it holds, its first news as a large
/// card, the rest as rows; a quiet day says so.
struct NewsDaySection: View {
    let day: NewsAgendaDay
    let today: Date
    var wished: Set<String> = []
    let onAction: (NewsAction) async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Self.title(day.day, today: today))
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.bottom, 2)
            if let first = day.cards.first {
                NewsAgendaLead(card: first, isWished: wished.contains(first.key), onAction: onAction)
                ForEach(day.cards.dropFirst()) { card in
                    NewsAgendaRow(card: card, isWished: wished.contains(card.key), onAction: onAction)
                }
            } else {
                Text(day.day > today ? "Rien d'annoncé ce jour-là." : "Rien de neuf ce jour-là.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 20)
    }

    /// "Aujourd'hui", "Hier", "Demain", else "Jeudi 12 novembre".
    static func title(_ day: Date, today: Date, calendar: Calendar = .current) -> String {
        let offset = calendar.dateComponents([.day], from: today, to: day).day ?? 0
        switch offset {
        case 0: return String(localized: "Aujourd'hui")
        case -1: return String(localized: "Hier")
        case 1: return String(localized: "Demain")
        default: return day.formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalizedFirst
        }
    }

    /// "3 nouvelles", "1 sortie", for VoiceOver on the strip's leaf.
    static func count(_ day: NewsAgendaDay, isFuture: Bool) -> String {
        let count = day.cards.count
        if isFuture { return count == 1 ? String(localized: "1 sortie") : String(localized: "\(count) sorties") }
        return count == 1 ? String(localized: "1 nouvelle") : String(localized: "\(count) nouvelles")
    }
}

private extension String {
    /// The weekday's capital a French date leaves out: "jeudi" → "Jeudi".
    var capitalizedFirst: String {
        guard let head = first else { return self }
        return String(head).localizedUppercase + dropFirst()
    }
}

/// A day's first news, large: its cover edge to edge on the leading side,
/// over the cover's own colours the emblem of what brought it — the prize
/// between its laurels, the friend, the follow — the title, the author, and
/// at the foot "Ajouter", as the series page draws its next volume.
private struct NewsAgendaLead: View {
    let card: NewsCard
    let isWished: Bool
    var coverWidth: CGFloat = 100
    let onAction: (NewsAction) async -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            NewsAgendaCover(book: card.cover, width: coverWidth)
            VStack(alignment: .leading, spacing: 0) {
                NewsCardEmblem(card: card)
                Text(card.cover.title)
                    .font(.headline)
                    .lineLimit(2)
                    .padding(.top, 7)
                Text(card.cover.authors.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
                    .padding(.top, 1)
                Spacer(minLength: 8)
                HStack(spacing: 8) {
                    Button {
                        Task { await onAction(.wish(card)) }
                    } label: {
                        Label(isWished ? "Dans vos envies" : "Ajouter", systemImage: isWished ? "checkmark" : "plus")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 13)
                            .frame(height: 30)
                            .background(.white, in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .disabled(isWished)
                    if card.isDismissable {
                        Button {
                            Task { await onAction(.dismiss(card)) }
                        } label: {
                            Image(systemName: "hand.thumbsdown")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .glassEffect(.regular.interactive(), in: .circle)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Pas intéressé")
                    }
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .padding(.trailing, 12)
        }
        .frame(minHeight: 150)
        .fixedSize(horizontal: false, vertical: true)
        .modifier(NewsAgendaCard(card: card, onAction: onAction))
    }
}

/// The day's other news, a row each: the cover on the leading side, what
/// brought it, the title, the author, the "+" at the trailing end.
private struct NewsAgendaRow: View {
    let card: NewsCard
    let isWished: Bool
    let onAction: (NewsAction) async -> Void

    var body: some View {
        HStack(spacing: 14) {
            NewsAgendaCover(book: card.cover, width: 61)
            VStack(alignment: .leading, spacing: 0) {
                NewsCardKicker(card: card, style: .fiche)
                Text(card.cover.title)
                    .font(.headline)
                    .lineLimit(1)
                    .padding(.top, 4)
                Text(card.cover.authors.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
                    .padding(.top, 1)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            NewsWishButton(card: card, isWished: isWished, size: 34, onAction: onAction)
                .padding(.trailing, 12)
        }
        .frame(minHeight: 92)
        .fixedSize(horizontal: false, vertical: true)
        .modifier(NewsAgendaCard(card: card, onAction: onAction))
    }
}

/// A cover filling its card's height on the leading side, cropped at its
/// foot rather than letterboxed.
private struct NewsAgendaCover: View {
    let book: Book
    let width: CGFloat

    var body: some View {
        Color.clear
            .frame(width: width)
            .frame(maxHeight: .infinity)
            .overlay(alignment: .top) {
                BookCover(book: book, width: width, showsFormatBadge: false, minHeight: width * 1.5, cornerRadius: 0)
            }
            .clipped()
            .accessibilityHidden(true)
    }
}

/// What every card of the day shares: the cover's colours behind it, the
/// rounded corners, a tap anywhere but its buttons opening the book.
private struct NewsAgendaCard: ViewModifier {
    let card: NewsCard
    let onAction: (NewsAction) async -> Void

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
            .onTapGesture { Task { await onAction(.open(card)) } }
            .background { CoverBackdrop(url: card.cover.coverURL, ground: .clear) }
            .clipShape(.rect(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.18), lineWidth: 1))
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text(card.cover.title))
            .accessibilityAddTraits(.isButton)
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

// MARK: - À la une

/// The releases of what the reader follows nearest today and the friends'
/// latest favourites, oldest first, as a rail of the day's large cards; it
/// opens on the nearest to come. A pill on each says how far it stands from
/// today.
struct NewsHighlights: View {
    let highlights: [NewsHighlight]
    let today: Date
    var opening: String?
    let onAction: (NewsAction) async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("À la une")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(highlights) { highlight in
                            NewsHighlightCard(highlight: highlight, today: today, onAction: onAction)
                                .frame(width: 300)
                                .id(highlight.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, 20, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
                .scrollIndicators(.hidden)
                .onAppear {
                    if let opening, highlights.count > 1 { proxy.scrollTo(opening, anchor: .leading) }
                }
            }
        }
    }

    /// "Aujourd'hui", "Hier", "Demain", "Il y a 7 jours", "Dans 2 jours".
    static func distance(_ day: Date, today: Date, calendar: Calendar = .current) -> String {
        let offset = calendar.dateComponents([.day], from: today, to: day).day ?? 0
        switch offset {
        case 0: return String(localized: "Aujourd'hui")
        case -1: return String(localized: "Hier")
        case 1: return String(localized: "Demain")
        case ..<0: return String(localized: "Il y a \(-offset) jours")
        default: return String(localized: "Dans \(offset) jours")
        }
    }
}

/// One headline: its cover edge to edge, over the cover's colours the follow
/// or the friend that brought it, the title, the author and, at the foot, how
/// far it stands from today.
private struct NewsHighlightCard: View {
    let highlight: NewsHighlight
    let today: Date
    let onAction: (NewsAction) async -> Void

    private var card: NewsCard { highlight.card }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            NewsAgendaCover(book: card.cover, width: 100)
            VStack(alignment: .leading, spacing: 0) {
                if case .friend = card {
                    NewsCardKicker(card: card, style: .fiche)
                } else if let follow = NewsCardText.follow(card) {
                    HStack(spacing: 6) {
                        Image(systemName: follow.symbol)
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 22, height: 22)
                            .background(.white.opacity(0.16), in: .circle)
                        Text(follow.text.capitalizedFirst)
                    }
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .frame(minHeight: 25)
                }
                Text(card.cover.title)
                    .font(.headline)
                    .lineLimit(2)
                    .padding(.top, 7)
                Text(card.cover.authors.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
                    .padding(.top, 1)
                Spacer(minLength: 8)
                Text(NewsHighlights.distance(highlight.day, today: today))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 9)
                    .frame(height: 22)
                    .glassEffect(.regular, in: .capsule)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .padding(.trailing, 12)
        }
        .frame(height: 150)
        .modifier(NewsAgendaCard(card: card, onAction: onAction))
    }
}

// MARK: - Prix de l'année

/// The year's prizes, one winner a page: the day's large card, its cover the
/// card's height, the prize between its laurels — both, when it won two —
/// "Ajouter" and "Pas intéressé"; the next card peeks at the edge, dots under.
struct NewsPrizesSlider: View {
    let cards: [NewsCard]
    var wished: Set<String> = []
    let onAction: (NewsAction) async -> Void

    @State private var selected: String?

    private var current: String? { selected ?? cards.first?.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NewsShelfHeader(title: "Prix de l'année") { Task { await onAction(.openDiscover) } }
            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(cards) { card in
                        NewsAgendaLead(card: card, isWished: wished.contains(card.key), coverWidth: 106, onAction: onAction)
                            .containerRelativeFrame(.horizontal) { width, _ in width - 40 }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $selected)
            .environment(\.colorScheme, .dark)
            if cards.count > 1 {
                HStack(spacing: 7) {
                    ForEach(cards) { card in
                        Capsule()
                            .fill(.primary.opacity(card.id == current ? 1 : 0.35))
                            .frame(width: card.id == current ? 22 : 7, height: 7)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
                .accessibilityHidden(true)
            }
        }
    }
}

// MARK: - The parts every card shares

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

    /// Which follow brought a release, out or to come: "votre série", "votre
    /// auteur", "guetté", the narrator.
    static func follow(_ card: NewsCard) -> (symbol: String, text: String)? {
        let release: UpcomingRelease
        switch card {
        case let .upcoming(announced), let .released(.release(announced, _)): release = announced
        case let .released(.narrator(news, _)): return (symbol(card), news.narrator)
        default: return nil
        }
        let text = switch release.source {
        case .saga: String(localized: "votre série")
        case .author: String(localized: "votre auteur")
        case .awaited: String(localized: "guetté")
        case .narrator: release.narrator ?? String(localized: "votre voix")
        }
        return (symbol(card), text)
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

    private var agenda: NewsAgenda {
        guard !empty else { return .empty() }
        return NewsAgenda(
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
                agenda: agenda,
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
