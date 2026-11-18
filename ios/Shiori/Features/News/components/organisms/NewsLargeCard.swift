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
                    NewsLargeCard(item: item, isWished: wished.isWished(item), onAction: onAction)
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
/// side, the person it is shown for in a pill on the cover's top and what
/// happened at its foot, as the covers of a rail say it; beside it the title,
/// the author, the outlined tags — how long is left, "Audio", a foreign
/// language — and at the foot "Envies" and the "+" of the other ways
/// to take it. A release's day sits in the corner as a calendar leaf.
struct NewsLargeCard: View {
    let item: NewsShelfItem
    var isWished = false
    let onAction: (NewsAction) async -> Void

    /// The home's "En cours" card's height (ReadingFeatureCard), which every
    /// large card of Actualité stands at, whatever its title or its tags say.
    static let height: CGFloat = 149
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
                height: Self.height
            )
            .overlay(alignment: .topLeading) {
                if item.pillName != nil {
                    NewsPersonPill(item: item, maxWidth: Self.coverWidth - 14)
                        .padding(7)
                }
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
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
                NewsCardButtons(
                    card: card,
                    isWished: isWished,
                    onAction: onAction
                )
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 14)
            .padding(.trailing, 14)
        }
        .frame(height: Self.height)
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

/// The foot of a large card: the pair "Envies" and "+" every book page
/// shares (WishAddButtons), and for a prize or a discovery "Pas intéressé".
/// The "+" opens the book page's add menu without the wish list: each format
/// the book may be taken in, then the editions to await. Where the three do
/// not fit beside a rail card's cover, the wish keeps its colour but loses
/// its words, so the card never grows past its frame over the next one.
struct NewsCardButtons: View {
    let card: NewsCard
    var isWished = false
    let onAction: (NewsAction) async -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            row(isCompact: false)
            row(isCompact: true)
        }
    }

    private func row(isCompact: Bool) -> some View {
        HStack(spacing: 8) {
            WishAddButtons(
                isWished: isWished,
                isCompact: isCompact,
                showsMenu: !formats.isEmpty || !awaitable.isEmpty,
                onToggle: { Task { await onAction(isWished ? .unwish(card) : .wish(card)) } }
            ) {
                BookAddMenuItems(
                    formats: formats,
                    owned: false,
                    awaitable: awaitable,
                    onAdd: { status, format in await onAction(.add(card, status, format)) },
                    onAwait: { format in Task { await onAction(.awaitEdition(card, format)) } },
                    showsWish: false
                )
            }
            if card.isDismissable {
                Button {
                    Task { await onAction(.dismiss(card)) }
                } label: {
                    circle("eye.slash")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Pas intéressé")
            }
        }
    }

    private func circle(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .glassEffect(.regular.interactive(), in: .circle)
            .contentShape(.circle)
    }

    /// The formats the book may be taken in, as the page it opens offers
    /// them; nothing for a book not out yet, which only the wish list holds.
    private var formats: [BookFormat] {
        switch card {
        case .upcoming: return []
        // A discovery's or a prize's page offers its own format alone.
        case .suggestion, .award: return [card.cover.format]
        // A friend's book or a release, as the friend's book page offers it.
        case .friend, .released: return card.cover.format.takenAs
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
    let maxWidth: CGFloat

    var body: some View {
        HStack(spacing: 5) {
            Group {
                if let avatar = item.avatar {
                    AccountAvatarView(avatar: avatar, firstName: item.person, size: 18)
                } else {
                    AuthorAvatar(initials: initials(of: item.person), portraitURL: item.portraitURL, size: 18)
                }
            }
            .clipShape(.circle)
            Text(item.pillName ?? "")
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.leading, 4)
        .padding(.trailing, 9)
        .frame(height: 26)
        .foregroundStyle(.white)
        .glassEffect(.regular, in: .capsule)
        .environment(\.colorScheme, .dark)
        .frame(maxWidth: maxWidth, alignment: .leading)
    }
}
