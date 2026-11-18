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

/// A rail of covers under its title, "Coups de cœur des amis ›": each cover
/// names its friend, author or narrator in a pill on its top corner and says
/// its news in its foot. The agenda's day, "À la une" and the follows' shelves
/// all draw their books with it.
struct NewsTileRail: View {
    let title: LocalizedStringKey
    let items: [NewsShelfItem]
    var onMore: (() -> Void)?
    let onAction: (NewsAction) async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NewsShelfHeader(title: title, onMore: onMore)
            NewsTileRow(items: items, onAction: onAction)
        }
    }
}

/// The covers of a rail, side by side, scrolling sideways.
struct NewsTileRow: View {
    let items: [NewsShelfItem]
    let onAction: (NewsAction) async -> Void

    var body: some View {
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

/// "Séries suivies": a card per followed series, as the home's "Séries en
/// cours", its news in the tag — the volume out, the next one's date.
struct NewsSeriesRail: View {
    let items: [NewsShelfItem]
    let onAction: (NewsAction) async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NewsShelfHeader(title: "Séries suivies") { Task { await onAction(.openLibrary(.seriesShelf(.all))) } }
            ScrollView(.horizontal) {
                LazyHStack(spacing: 13) {
                    ForEach(items) { item in
                        SeriesShowCard(series: Self.series(item), tag: item.word, isCompact: true, releaseDate: item.day) {
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

/// One cover of a rail: the book as a poster, its news in the foot, and the
/// person it is shown for — a friend's face and first name, an author's or a
/// narrator's portrait and "M. Wells" — in a white pill on glass on its top
/// corner. Nothing under the cover.
struct NewsPersonTile: View {
    let item: NewsShelfItem
    var width: CGFloat = 102
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            PosterCover(book: item.card.cover, label: PosterLabel(caption: item.caption, rating: item.rating), width: width)
                .overlay(alignment: .topLeading) {
                    if item.pillName != nil {
                        NewsPersonPill(item: item, maxWidth: width - 12).padding(6)
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text([item.person, item.card.cover.title, item.caption].compactMap(\.self).joined(separator: ", ")))
        .accessibilityAddTraits(.isButton)
    }

    /// "Martha Wells" → "M. Wells", so the name holds in the pill; a single
    /// name stays whole.
    nonisolated static func shortName(_ name: String?) -> String {
        let words = (name ?? "").split(separator: " ")
        guard words.count > 1, let first = words.first?.first, let last = words.last else { return name ?? "" }
        return "\(first). \(last)"
    }
}

/// "Liste d'envies": the editions the reader awaits still to come, as
/// posters, their day or "En vue" in the cover's foot, "Audio" in its corner.
struct NewsWishesRail: View {
    let items: [NewsShelfItem]
    let onAction: (NewsAction) async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NewsShelfHeader(title: "Liste d'envies") { Task { await onAction(.openLibrary(.wishlist)) } }
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
            NewsTileRail(title: "Activité des amis", items: shelves.activity) { _ in }
            NewsTileRail(title: "Coups de cœur des amis", items: shelves.loves) { _ in }
            NewsSeriesRail(items: shelves.series) { _ in }
            NewsTileRail(title: "Auteurs préférés", items: shelves.authors) { _ in }
            NewsTileRail(title: "Narrateurs préférés", items: shelves.narrators) { _ in }
            NewsWishesRail(items: shelves.wishes) { _ in }
        }
    }
    .preferredColorScheme(.dark)
}
