import SwiftUI

/// A shelf of Découvrir under its title: up to three books, each as a large
/// card, a lone one across the page and the next one peeking in from two on;
/// more than three, the rail of covers.
struct NewsShelf: View {
    let title: LocalizedStringKey
    let items: [NewsShelfItem]
    var onMore: (() -> Void)?
    /// The cards' books just wished for, by `NewsCard.key`.
    var wished: NewsWishes = []
    let onAction: (NewsAction) async -> Void

    /// How many books a shelf still draws as large cards.
    static let cardLimit = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NewsShelfHeader(title: title, onMore: onMore)
            if items.count <= Self.cardLimit {
                NewsCardRow(items: items, wished: wished, onAction: onAction)
            } else {
                NewsTileRow(items: items, onAction: onAction)
            }
        }
    }
}

/// Large cards side by side, scrolling sideways: a lone card spans the page,
/// from two on each is narrower so the next one peeks in.
struct NewsCardRow: View {
    let items: [NewsShelfItem]
    var wished: NewsWishes = []
    let onAction: (NewsAction) async -> Void

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 12) {
                ForEach(items) { item in
                    NewsLargeCard(
                        item: item, isWished: wished.isWished(item), wishes: wished,
                        height: NewsLargeCard.height(for: items), onAction: onAction
                    )
                        .containerRelativeFrame(.horizontal) { width, _ in
                            SeriesReleaseCard.railWidth(width, count: items.count)
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

/// One book of a short shelf, large: its cover edge to edge on the leading
/// side, what happened at its foot, as the covers of a rail say it; beside
/// it the person it is shown for in a pill with a chevron, which opens them —
/// the Amis tab narrowed to a friend, an author's or a narrator's page —
/// then the author, the title, the outlined tags — how long is left, "Audio", a foreign
/// language — and at the foot "+ Ajouter", or "Ajouté" for a book the
/// reader holds already. A
/// release's day sits in the corner as a calendar leaf.
struct NewsLargeCard: View {
    let item: NewsShelfItem
    var isWished = false
    /// What the cards' buttons made of their books, and the cards turned
    /// down, drawn black and white.
    var wishes: NewsWishes = []
    /// The row's height: every card of a row stands as tall as the others.
    var height: CGFloat = NewsLargeCard.height
    let onAction: (NewsAction) async -> Void

    /// The home's "En cours" card's height (ReadingFeatureCard), which every
    /// large card of Actualité stands at, whatever its title or its tags say.
    static let height: CGFloat = 149
    /// What a person's pill adds over the text: its height and the gap under
    /// it, so the title keeps its two lines.
    static let pillRoom: CGFloat = 26

    /// A row's height: taller by the pill's room when one of its cards
    /// carries a pill, so the cards stay the same height side by side.
    static func height(for items: [NewsShelfItem]) -> CGFloat {
        items.contains { $0.pillName != nil } ? height + pillRoom : height
    }
    /// The "En cours" card's cover width.
    static let coverWidth: CGFloat = ReadingFeatureCard.coverWidth
    /// The calendar leaf's width and its margin, kept clear by the text.
    private static let leafRoom: CGFloat = 58

    private var card: NewsCard { item.card }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            PosterCover(
                book: card.cover,
                label: PosterLabel(caption: item.word, rating: item.rating),
                width: Self.coverWidth,
                showsEditionTags: false,
                // Edge to edge over the card's whole height, no rim, as the
                // "En cours" card: its own corners round it.
                corner: 0,
                height: height
            )
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                if item.pillName != nil {
                    NewsPersonPill(item: item, isLarge: true) { target in
                        Task { await onAction(.openPerson(target)) }
                    }
                    .padding(.trailing, item.day == nil ? 0 : Self.leafRoom - 14)
                    .padding(.bottom, 7)
                }
                // As the "En cours" card: who wrote it over the title, the
                // title on two lines at most, then the tags.
                Text(card.cover.authors.joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
                    .padding(.trailing, item.day == nil ? 0 : Self.leafRoom)
                Text(card.cover.title)
                    .font(.title3.weight(.bold))
                    .lineLimit(2)
                    .layoutPriority(1)
                    .padding(.trailing, item.day == nil ? 0 : Self.leafRoom)
                if !tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(tags, id: \.self) { OutlinedTag(text: $0, isFrosted: false) }
                    }
                    .padding(.top, 4)
                }
                // No floor under the gap: two lines of title and the tags
                // keep their room at the "En cours" card's height.
                Spacer(minLength: 0)
                NewsCardButtons(card: card, isWished: isWished, wishes: wishes, onAction: onAction)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 14)
            .padding(.trailing, 14)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .topTrailing) {
            if let date = item.day {
                ReleaseDateBadge(date: date, onGlass: true)
                    .padding(10)
            }
        }
        .contentShape(.rect)
        .onTapGesture { Task { await onAction(.open(card)) } }
        .environment(\.colorScheme, .dark)
        .background { CoverBackdrop(url: card.cover.coverURL, ground: .clear, tint: card.cover.coverGround) }
        // Turned down from its eye: black and white until the reader comes
        // back to the page.
        .saturation(wishes.isTurnedDown(card) ? 0 : 1)
        .animation(.smooth, value: wishes.isTurnedDown(card))
        .clipShape(.rect(cornerRadius: 18))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text([item.person, card.cover.title, item.word].compactMap(\.self).joined(separator: ", ")))
        .accessibilityAddTraits(.isButton)
    }

    /// "Audio" first for a recording, what matters most, then how long is
    /// left before a release ahead, then the language when it is not the
    /// phone's.
    private var tags: [String] {
        var tags: [String] = []
        if card.cover.format == .audiobook { tags.append(String(localized: "Audio")) }
        if let date = item.day, let countdown = ReleaseDateText.countdown(date) { tags.append(countdown) }
        if let language = card.cover.language, language.isForeign { tags.append(language.code) }
        return tags
    }
}

/// The foot of a large card: "+ Ajouter", the one button every book page
/// shares (AddMenuButton), and for a prize or a discovery the closed eye.
/// Its menu offers each format the book may be taken in, the wish list, then
/// the editions to await; the action chosen is said in its place, a second
/// tap taking it back. A book the reader holds already says "Ajouté". The
/// eye turns the card black and white in one tap; a second, or a tap on the
/// greyed "+ Ajouter", brings the colour back.
struct NewsCardButtons: View {
    let card: NewsCard
    var isWished = false
    var wishes: NewsWishes = []
    let onAction: (NewsAction) async -> Void

    private var isTurnedDown: Bool { wishes.isTurnedDown(card) }
    private var done: TakenState? { wishes.state(of: card, isWished: isWished) }

    var body: some View {
        HStack(spacing: 8) {
            AddMenuButton(
                done: done,
                isTurnedDown: isTurnedDown,
                onReconsider: { act(.reconsider(card)) },
                onUndo: done == .owned ? nil : { act(.undo(card, isWished: isWished)) }
            ) {
                BookAddMenuItems(
                    formats: formats,
                    owned: false,
                    awaitable: awaitable,
                    onAdd: { status, format in await onAction(.add(card, status, format)) },
                    onAwait: { format in act(.awaitEdition(card, format)) },
                    onWish: { await onAction(.wish(card)) }
                )
            }
            if card.isDismissable {
                NotInterestedToggle(isOn: isTurnedDown) { turnDown in
                    await onAction(turnDown ? .dismiss(card) : .reconsider(card))
                }
                .disabled(done != nil && !isTurnedDown)
                .opacity(done != nil && !isTurnedDown ? 0.45 : 1)
            }
        }
    }

    private func act(_ action: NewsAction) {
        Task { await onAction(action) }
    }

    /// The formats the book may be taken in: the book and its recording
    /// once out; nothing for a book not out yet, which the wish list holds.
    private var formats: [BookFormat] {
        switch card {
        case .upcoming: []
        default: card.cover.format.takenAs
        }
    }

    /// The editions that may be awaited: those the page of a discovery or a
    /// prize offers, otherwise the one in the phone's language for a book read
    /// in another.
    private var awaitable: [ReleaseFormat] {
        switch card {
        case let .suggestion(suggestion): return suggestion.awaitableFormats
        case let .award(winner): return winner.awaitableFormats
        default: break
        }
        guard let language = card.cover.language, language.isForeign else { return [] }
        return [card.cover.format == .audiobook ? .audiobook : .book]
    }
}

/// The person a cover is shown for — a friend's face and first name, an
/// author's or a narrator's portrait and "M. Wells" — in a white pill on glass.
struct NewsPersonPill: View {
    let item: NewsShelfItem
    /// The large card's pill, over its title: larger, with a chevron, and a
    /// button when the card names someone it can open.
    var isLarge = false
    var maxWidth: CGFloat = .infinity
    var onOpen: ((NewsPersonTarget) -> Void)?

    private var avatarSize: CGFloat { isLarge ? 24 : 18 }

    var body: some View {
        if isLarge, let target = item.personTarget, let onOpen {
            Button { onOpen(target) } label: { pill }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(item.pillName ?? ""))
        } else {
            pill
        }
    }

    private var pill: some View {
        HStack(spacing: isLarge ? 7 : 5) {
            Group {
                if let avatar = item.avatar {
                    AccountAvatarView(avatar: avatar, firstName: item.person, size: avatarSize)
                } else {
                    AuthorAvatar(initials: initials(of: item.person), portraitURL: item.portraitURL, size: avatarSize)
                }
            }
            .clipShape(.circle)
            Text(item.pillName ?? "")
                .font(isLarge ? .subheadline.weight(.semibold) : .caption2.weight(.semibold))
                .lineLimit(1)
            if isLarge, item.personTarget != nil {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .padding(.leading, 4)
        .padding(.trailing, isLarge ? 11 : 9)
        .frame(height: isLarge ? 32 : 26)
        .foregroundStyle(.white)
        .glassEffect(.regular, in: .capsule)
        .contentShape(.capsule)
        .environment(\.colorScheme, .dark)
        .frame(maxWidth: maxWidth, alignment: .leading)
    }
}

#Preview("Grandes cartes") {
    let shelves = NewsShelves(
        released: NewsFeedLayout.released(releases: UpcomingRelease.releasedPreviews, narrator: [.preview], format: nil),
        moves: NewsFeedLayout.friendSections(events: FeedEvent.previews).flatMap(\.moves),
        upcoming: UpcomingRelease.previews,
        today: .now,
        calendar: .current
    )
    ScrollView {
        VStack(spacing: 16) {
            ForEach((shelves.loves + shelves.series).prefix(3)) { item in
                NewsLargeCard(item: item) { _ in }
            }
        }
        .padding(20)
    }
    .preferredColorScheme(.dark)
}
