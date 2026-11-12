import SwiftUI

/// A shelf's title over its rail, "Séries suivies ›": the chevron only where
/// the title leads somewhere.
struct NewsShelfHeader: View {
    let title: LocalizedStringKey
    var onMore: (() -> Void)?

    var body: some View {
        Group {
            if let onMore {
                Button(action: onMore) { label(chevron: true) }
                    .buttonStyle(.plain)
            } else {
                label(chevron: false)
            }
        }
        .padding(.horizontal, 20)
    }

    private func label(chevron: Bool) -> some View {
        HStack(spacing: 6) {
            Text(title)
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .font(.title2.weight(.bold))
        .accessibilityAddTraits(.isHeader)
    }
}

/// "Coups de cœur des amis": the books the friends hearted lately, as the
/// home's posters, the friend's name in the cover's foot after a heart.
struct NewsLovesRail: View {
    let moves: [FriendMove]
    let onAction: (NewsAction) async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NewsShelfHeader(title: "Coups de cœur des amis")
            PosterRow(
                items: moves.map { move in
                    PosterRow.Item(book: move.lead.cover, caption: "\u{2665}\u{FE0E} \(move.lead.friendName)") {
                        Task { await onAction(.open(.friend(move))) }
                    }
                },
                onOpen: { _ in }
            )
            .contentMargins(.horizontal, 20, for: .scrollContent)
        }
    }
}

/// "Séries suivies": a card per followed series, as the home's "Séries en
/// cours", its news in the tag — the volume out, the next one's date.
struct NewsSeriesRail: View {
    let items: [NewsShelfItem]
    let onAction: (NewsAction) async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NewsShelfHeader(title: "Séries suivies") { Task { await onAction(.openUpcoming) } }
            ScrollView(.horizontal) {
                LazyHStack(spacing: 13) {
                    ForEach(items) { item in
                        SeriesShowCard(series: Self.series(item), tag: item.caption, isCompact: true) {
                            Task { await onAction(.open(item.card)) }
                        }
                        .frame(width: 200, height: 128)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
        }
    }

    /// The series as the home's card draws it, its volume's cover across: no
    /// count of the volumes read, which Découvrir does not hold.
    static func series(_ item: NewsShelfItem) -> Dashboard.SeriesProgress {
        let cover = item.card.cover
        let name: String = switch item.card {
        case let .released(.release(release, _)), let .upcoming(release): release.seriesName ?? cover.title
        default: cover.title
        }
        return Dashboard.SeriesProgress(
            id: item.id,
            name: name,
            isAudio: cover.format == .audiobook,
            readCount: 0,
            totalCount: 0,
            coverURL: cover.coverURL
        )
    }
}

/// "Auteurs préférés" and "Narrateurs préférés": the new book's cover, the
/// person's face on its corner, their name and the book's news under it.
struct NewsPeopleRail: View {
    let title: LocalizedStringKey
    let items: [NewsShelfItem]
    let onAction: (NewsAction) async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NewsShelfHeader(title: title) { Task { await onAction(.openUpcoming) } }
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 13) {
                    ForEach(items) { item in
                        NewsPersonTile(item: item) { Task { await onAction(.open(item.card)) } }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
        }
    }
}

/// One cover of a person's shelf: the book as a poster, the person's portrait
/// or initials on its lower corner, "M. Wells" and "Tome 8 annoncé" under it.
struct NewsPersonTile: View {
    let item: NewsShelfItem
    var width: CGFloat = 102
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 0) {
                PosterCover(book: item.card.cover, caption: "", width: width)
                    .overlay(alignment: .bottomLeading) {
                        AuthorAvatar(initials: initials(of: item.person), portraitURL: item.portraitURL, size: 30)
                            .overlay { Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1) }
                            .background(Circle().fill(Color(.systemBackground)).padding(-2))
                            .padding(.leading, 8)
                            .offset(y: 13)
                    }
                Text(Self.shortName(item.person))
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .padding(.top, 20)
                Text(item.caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    // "Annoncé · 22 déc." whole, a touch smaller.
                    .minimumScaleFactor(0.85)
                    .padding(.top, 2)
            }
            .frame(width: width, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(item.person ?? ""), \(item.card.cover.title), \(item.caption)"))
        .accessibilityAddTraits(.isButton)
    }

    /// "Martha Wells" → "M. Wells", so the name holds on one line under the
    /// cover; a single name stays whole.
    static func shortName(_ name: String?) -> String {
        let words = (name ?? "").split(separator: " ")
        guard words.count > 1, let first = words.first?.first, let last = words.last else { return name ?? "" }
        return "\(first). \(last)"
    }
}

/// "Vos envies": the editions the reader awaits, as posters, their day or
/// "Sorti" in the cover's foot, "Audio" in its corner.
struct NewsWishesRail: View {
    let items: [NewsShelfItem]
    let onAction: (NewsAction) async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NewsShelfHeader(title: "Vos envies") { Task { await onAction(.openUpcoming) } }
            PosterRow(
                items: items.map { item in
                    PosterRow.Item(book: item.card.cover, caption: item.caption) {
                        Task { await onAction(.open(item.card)) }
                    }
                },
                onOpen: { _ in }
            )
            .contentMargins(.horizontal, 20, for: .scrollContent)
        }
    }
}

#Preview("Étagères") {
    let shelves = NewsShelves(
        released: NewsFeedLayout.released(releases: UpcomingRelease.releasedPreviews, narrator: [.preview], format: nil),
        moves: NewsFeedLayout.friendSections(events: FeedEvent.previews).flatMap(\.moves),
        upcoming: UpcomingRelease.previews,
        today: .now,
        calendar: .current
    )
    ScrollView {
        VStack(alignment: .leading, spacing: 30) {
            NewsLovesRail(moves: shelves.loves) { _ in }
            NewsSeriesRail(items: shelves.series) { _ in }
            NewsPeopleRail(title: "Auteurs préférés", items: shelves.authors) { _ in }
            NewsPeopleRail(title: "Narrateurs préférés", items: shelves.narrators) { _ in }
            NewsWishesRail(items: shelves.wishes) { _ in }
        }
    }
    .preferredColorScheme(.dark)
}
