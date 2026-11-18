import SwiftUI

/// Everything the Découvrir page can ask for.
enum NewsAction {
    /// A card's book, on the page the rest of the app opens it on.
    case open(NewsCard)
    /// "+": the card's book onto the wish list.
    case wish(NewsCard)
    /// "Pas intéressé" on a discovery or a prize.
    case dismiss(NewsCard)
    /// The "+" of a large card: onto the pile or among the books read, in
    /// the format given.
    case add(NewsCard, CopiedStatus, BookFormat)
    /// The "+" of a large card: the edition in the phone's language awaited.
    case awaitEdition(NewsCard, ReleaseFormat)
    /// A rail's title: the Library view that answers it, already filtered —
    /// "Séries suivies ›" the series, "Auteurs préférés ›" and "Narrateurs
    /// préférés ›" the hearted ones, "Liste d'envies ›" the wish list.
    case openLibrary(LibraryDestination)
    case invite
    case openAlerts
    case refresh
}

/// The Découvrir tab, pure: an agenda of what the book world brought the
/// reader. At the top "À la une", a rail of covers: the friends' coups de
/// cœur and the releases of what the reader follows, out in the last twenty
/// days or due in the next thirty; then a strip of the days that bring
/// something, a month back and every announced day ahead, each with a dot per piece of
/// news, over every day's covers in one rail the strip follows; then what each friend did
/// last, the friends' coups de cœur, the year's prizes one winner a page, and
/// a shelf per follow — the followed series, the favourite authors and
/// narrators, the wish list. Every rail is left out when empty.
struct NewsPage: View {
    let agenda: NewsAgenda
    /// The cards' books just wished for, by `NewsCard.key`.
    var wished: Set<String> = []
    let isLoading: Bool
    let errorMessage: String?
    let alertsSilenced: Bool
    let onAction: (NewsAction) async -> Void

    /// The first day whose covers are on the agenda's rail.
    @State private var lead: Date?

    private func act(_ action: NewsAction) {
        Task { await onAction(action) }
    }

    private var day: NewsAgendaDay? {
        agenda.days.first { $0.day == (lead ?? agenda.openingDay) }
    }

    var body: some View {
        content
            .navigationTitle("Actualité")
            // The home's bar: the name on the left, the buttons on the right,
            // sent away together by scrolling down.
            .scrollAwayBar(String(localized: "Actualité")) {
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
            EmptyState.failure("Actualité indisponible", message: errorMessage) {
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
                        if !agenda.headlines.isEmpty {
                            NewsShelf(title: "À la une", items: agenda.headlines, wished: wished, onAction: onAction)
                                .padding(.bottom, 30)
                        }
                        if !agenda.days.isEmpty {
                            NewsAgendaSection(
                                days: agenda.days,
                                today: agenda.today,
                                opening: agenda.openingDay,
                                lead: $lead,
                                wished: wished,
                                onAction: onAction
                            )
                        }
                    }
                    .environment(\.colorScheme, .dark)
                    // The first cover's colours run up under the title and
                    // fade into the page.
                    .background(alignment: .top) {
                        CoverBackdrop(
                            url: (agenda.headlines.first?.card ?? day?.cards.first)?.cover.coverURL,
                            fadeHeight: 160,
                            ground: Color(.systemBackground)
                        )
                        .frame(height: 760)
                        .offset(y: -300)
                        .animation(.smooth, value: day?.id)
                    }
                    shelves
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

    /// The friends, the prizes, then a rail per follow, each left out when it
    /// holds nothing.
    @ViewBuilder
    private var shelves: some View {
        let shelves = agenda.shelves
        if !shelves.activity.isEmpty {
            NewsShelf(title: "Activité des amis", items: shelves.activity, wished: wished, onAction: onAction).padding(.top, 30)
        }
        if !shelves.loves.isEmpty {
            NewsShelf(title: "Coups de cœur des amis", items: shelves.loves, wished: wished, onAction: onAction).padding(.top, 30)
        }
        if !prizes.isEmpty {
            NewsPrizesSlider(cards: prizes, wished: wished, onAction: onAction).padding(.top, 30)
        }
        if !shelves.series.isEmpty {
            NewsSeriesRail(items: shelves.series, onAction: onAction).padding(.top, 30)
        }
        if !shelves.authors.isEmpty {
            NewsShelf(title: "Auteurs préférés", items: shelves.authors, onMore: { act(.openLibrary(.authors(.loved))) }, wished: wished, onAction: onAction)
                .padding(.top, 30)
        }
        if !shelves.narrators.isEmpty {
            NewsShelf(title: "Narrateurs préférés", items: shelves.narrators, onMore: { act(.openLibrary(.narrators(.loved))) }, wished: wished, onAction: onAction)
                .padding(.top, 30)
        }
        if !shelves.wishes.isEmpty {
            if shelves.wishes.count <= NewsShelf.cardLimit {
                NewsShelf(title: "Liste d'envies", items: shelves.wishes, onMore: { act(.openLibrary(.wishlist)) }, wished: wished, onAction: onAction)
                    .padding(.top, 30)
            } else {
                NewsWishesRail(items: shelves.wishes, onAction: onAction).padding(.top, 30)
            }
        }
    }

    /// With no friend yet, the invitation in their place.
    private var invitation: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Vos amis")
                .font(.title2.weight(.bold))
            // The invitation is made on the server before its sheet opens:
            // the capsule turns meanwhile, as on Partagé.
            AsyncButton {
                await onAction(.invite)
            } label: {
                Label("Inviter un ami", systemImage: "person.badge.plus")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .frame(height: 40)
                    .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .capsule)
            Text("Ce que lisent et aiment vos amis s'affichera ici.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - L'agenda

/// The agenda: its title, the strip of the days that bring something — the
/// month over the first leaf of each, a dot under each leaf for its news — and
/// under the strip every day's covers in one rail, oldest first, with no end
/// ahead — up to three, large cards as on the other shelves. The rail opens on the opening day's covers; as it scrolls, the days
/// whose covers are on screen turn white in the strip, which follows it; a
/// leaf brings the rail to its day.
struct NewsAgendaSection: View {
    let days: [NewsAgendaDay]
    let today: Date
    let opening: Date?
    /// The first day on screen, for the backdrop's colours.
    @Binding var lead: Date?
    /// The cards' books just wished for, by `NewsCard.key`.
    var wished: Set<String> = []
    let onAction: (NewsAction) async -> Void

    /// The days whose covers are on screen.
    @State private var shown: Set<Date> = []
    /// Whether the rail has been moved by the reader: until then it rests on
    /// the opening day, whatever the first layout passes report.
    @State private var isMoved = false
    @State private var rail = ScrollPosition(idType: String.self)
    @State private var strip = ScrollPosition(idType: Date.self)

    struct Entry: Identifiable {
        let id: String
        let day: Date
        let item: NewsShelfItem
    }

    /// Every day's covers in a row, each keyed by its day so a card news on
    /// two days keeps two places.
    static func entries(_ days: [NewsAgendaDay]) -> [Entry] {
        days.flatMap { day in
            day.cards.map { card in
                Entry(
                    id: "\(Int(day.day.timeIntervalSinceReferenceDate))~\(card.id)",
                    day: day.day,
                    item: NewsShelves.item(card, calendar: .current)
                )
            }
        }
    }

    var body: some View {
        let entries = Self.entries(days)
        VStack(alignment: .leading, spacing: 10) {
            Text("L'agenda")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
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
                            NewsDayLeaf(day: day, isToday: day.day == today, isPicked: shown.contains(day.day)) {
                                bring(day.day, entries: entries)
                            }
                        }
                        .id(day.day)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .scrollPosition($strip)
            .scrollIndicators(.hidden)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: entries.count <= NewsShelf.cardLimit ? 12 : 13) {
                    ForEach(entries) { entry in
                        if entries.count <= NewsShelf.cardLimit {
                            NewsLargeCard(item: entry.item, isWished: wished.contains(entry.item.card.key), onAction: onAction)
                                .containerRelativeFrame(.horizontal) { width, _ in
                                    SeriesReleaseCard.railWidth(width, count: entries.count)
                                }
                                .id(entry.id)
                        } else {
                            NewsPersonTile(item: entry.item) { Task { await onAction(.open(entry.item.card)) } }
                                .id(entry.id)
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition($rail)
            .scrollIndicators(.hidden)
            .onScrollPhaseChange { _, phase in
                if phase == .interacting { isMoved = true }
            }
            .onScrollTargetVisibilityChange(idType: String.self, threshold: 0.5) { ids in
                guard isMoved else { return }
                let visible = Set(ids)
                let onScreen = Set(entries.filter { visible.contains($0.id) }.map(\.day))
                guard !onScreen.isEmpty, onScreen != shown else { return }
                shown = onScreen
                lead = onScreen.min()
                if let first = onScreen.min() {
                    withAnimation(.smooth) { strip.scrollTo(id: first, anchor: .leading) }
                }
            }
            .padding(.top, 4)
        }
        .onAppear {
            guard shown.isEmpty, let opening else { return }
            shown = [opening]
            lead = opening
            strip.scrollTo(id: opening, anchor: .leading)
            if let first = entries.first(where: { $0.day == opening }) {
                rail.scrollTo(id: first.id, anchor: .leading)
            }
        }
    }

    /// Brings the rail to the day's first cover.
    private func bring(_ day: Date, entries: [Entry]) {
        guard let first = entries.first(where: { $0.day == day }) else { return }
        isMoved = true
        withAnimation(.smooth) { rail.scrollTo(id: first.id, anchor: .leading) }
    }

    /// Whether the leaf at `index` is the first of its month.
    static func opensMonth(_ index: Int, in days: [NewsAgendaDay], calendar: Calendar = .current) -> Bool {
        index == 0 || !calendar.isDate(days[index].day, equalTo: days[index - 1].day, toGranularity: .month)
    }

    /// "NOV.", over the month's first leaf.
    static func month(_ day: Date) -> String {
        day.formatted(.dateTime.month(.abbreviated)).localizedUppercase
    }

    /// "3 nouvelles", "1 nouvelle", for VoiceOver on the strip's leaf.
    static func count(_ day: NewsAgendaDay) -> String {
        let count = day.cards.count
        return count == 1 ? String(localized: "1 nouvelle") : String(localized: "\(count) nouvelles")
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
        .accessibilityValue(Text(NewsAgendaSection.count(day)))
        .accessibilityAddTraits(isPicked ? .isSelected : [])
    }
}

/// A day's first news, large: its cover edge to edge on the leading side,
/// over the cover's own colours the emblem of what brought it — the prize
/// between its laurels, the friend, the follow — the title, the author, and
/// at the foot the large cards' buttons: "Liste d'envies", "+", and "Pas
/// intéressé" for a prize.
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
                NewsCardButtons(card: card, isWished: isWished, onAction: onAction)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .padding(.trailing, 12)
        }
        // Every large card of the page stands at one height, whatever its
        // title or its prizes say.
        .frame(height: NewsLargeCard.height)
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

// MARK: - Prix de l'année

/// The year's prizes, one winner a page: the day's large card, its cover the
/// card's height, the prize between its laurels — both, when it won two —
/// "Liste d'envies", "+" and "Pas intéressé"; the next card peeks at the edge,
/// which says enough that more follow.
struct NewsPrizesSlider: View {
    let cards: [NewsCard]
    var wished: Set<String> = []
    let onAction: (NewsAction) async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NewsShelfHeader(title: "Prix de l'année")
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(cards) { card in
                        NewsAgendaLead(card: card, isWished: wished.contains(card.key), coverWidth: 106, onAction: onAction)
                            .containerRelativeFrame(.horizontal) { width, _ in
                                SeriesReleaseCard.railWidth(width, count: cards.count)
                            }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .environment(\.colorScheme, .dark)
        }
    }
}

// MARK: - The parts every card shares

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

extension NewsAgenda {
    /// The agenda alone, its releases cut to the `cards` nearest the opening
    /// day, for the previews of a short agenda.
    func agendaOnly(cards: Int) -> NewsAgenda {
        let opening = openingDay ?? today
        let kept = days
            .flatMap { day in day.cards.map { (day: day.day, card: $0) } }
            .sorted { abs($0.day.timeIntervalSince(opening)) < abs($1.day.timeIntervalSince(opening)) }
            .prefix(cards)
        let short = Dictionary(grouping: kept, by: \.day)
            .map { NewsAgendaDay(day: $0.key, cards: $0.value.map(\.card)) }
            .sorted { $0.day < $1.day }
        return NewsAgenda(days: short, today: today, headlines: [], prizes: [], hasFriends: true)
    }
}

private struct NewsPagePreview: View {
    var events: [FeedEvent] = FeedEvent.previews + FeedEvent.sameStartPreviews
    var released = true
    var isLoading = false
    var errorMessage: String?
    var empty = false
    /// Keeps only the agenda, cut to this many releases.
    var agendaCards: Int?

    private var agenda: NewsAgenda {
        guard !empty else { return .empty() }
        guard let agendaCards else { return full }
        return full.agendaOnly(cards: agendaCards)
    }

    private var full: NewsAgenda {
        NewsAgenda(
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
#Preview("Agenda, une sortie") { NewsPagePreview(agendaCards: 1) }
#Preview("Agenda, trois sorties") { NewsPagePreview(agendaCards: 3) }
#Preview("Vide") { NewsPagePreview(empty: true) }
#Preview("Loading") { NewsPagePreview(isLoading: true, empty: true) }
#Preview("Failed") { NewsPagePreview(errorMessage: "Le réseau est indisponible.", empty: true) }
