import SwiftUI

/// Everything the Actualités page can ask for.
enum NewsAction {
    case selectFormat(BookFormat?)
    case selectFriend(String?)
    case openFriendBook(FeedEvent)
    case addFriendBook(FeedEvent, CopiedStatus, BookFormat)
    case wishFriendBook(FeedEvent)
    case awaitFriendBook(FeedEvent, ReleaseFormat)
    case addReleased(ReleasedItem, CopiedStatus, BookFormat)
    case wishReleased(ReleasedItem)
    case awaitReleased(ReleasedItem, ReleaseFormat)
    case openAuthor(UpcomingRelease)
    case openUpcoming
    case openNarrator(NarratorNews)
    case invite
    case openAlerts
    case prefetch(String)
    case loadMore
    case refresh
}

/// The Actualités page, pure: one feed. "À venir" at the top, its release
/// cards in a rail and its title opening the full list; the friends as
/// stories, the format pills, then over the last thirty days what came out
/// among the series, authors, narrators and awaited editions the reader
/// follows mixed with what their friends did, under journal periods, the same
/// move by several of them on one line. No row carries a "…": slid to the
/// left, each opens the menu that takes the book, wishes for it or awaits its
/// recording. The pages a tap opens are the screen's.
struct NewsPage: View {
    let feed: [NewsFeedSection]
    /// The rows' books just taken, wished for or awaited: a friend's by its
    /// book id, a release by its row id.
    var taken: Set<String> = []
    var wished: Set<String> = []
    var awaited: Set<String> = []
    let calendar: ReleaseCalendar
    let format: BookFormat?
    /// The formats the pills offer: those the feed holds something in.
    var pillFormats: [BookFormat] = NewsFeedLayout.pillFormats
    let stories: [FriendStory]
    let friendId: String?
    let hasMore: Bool
    let pageFailed: Bool
    let isLoading: Bool
    let errorMessage: String?
    let alertsSilenced: Bool
    let onAction: (NewsAction) async -> Void

    /// A tap that only opens something: nothing to wait for.
    private func act(_ action: NewsAction) {
        Task { await onAction(action) }
    }

    private var isEmpty: Bool { feed.isEmpty && calendar.releases.isEmpty && stories.isEmpty }

    var body: some View {
        content
            .navigationTitle("Actualités")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    DiscoverAlertsButton(isSilenced: alertsSilenced) { act(.openAlerts) }
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if let errorMessage, isEmpty, !isLoading {
            EmptyState.failure("Actualités indisponibles", message: errorMessage) {
                await onAction(.refresh)
            }
        } else if isLoading, isEmpty {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if !calendar.releases.isEmpty {
                        UpcomingRail(
                            releases: calendar.dated,
                            onOpenList: { act(.openUpcoming) },
                            onOpen: { release in act(release.author == nil ? .openUpcoming : .openAuthor(release)) }
                        )
                        .padding(.top, 8)
                    }
                    if !stories.isEmpty {
                        FriendStoriesRail(
                            stories: stories,
                            selected: friendId,
                            onSelect: { act(.selectFriend($0)) },
                            onInvite: { await onAction(.invite) }
                        )
                        .padding(.top, calendar.releases.isEmpty ? 4 : 18)
                    }
                    FilterPills(
                        pills: pillFormats.map { .init(id: $0.rawValue, label: $0.pillLabel) },
                        selected: format?.rawValue
                    ) { id in
                        act(.selectFormat(id.flatMap(BookFormat.init(rawValue:))))
                    }
                    .padding(.top, 14)
                    lines
                }
                .padding(.bottom, 24)
            }
            .refreshable { await onAction(.refresh) }
        }
    }

    // MARK: - The feed

    @ViewBuilder
    private var lines: some View {
        if feed.isEmpty {
            Text("Rien n'est sorti ces 30 derniers jours.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 8)
                .accessibilityIdentifier("news-released-empty")
        } else {
            ForEach(feed) { section in
                sectionTitle(section.title)
                ForEach(section.items) { item in
                    switch item {
                    case let .released(released): releasedRow(released)
                    case let .friend(move): friendRow(move)
                    }
                }
            }
        }
        if hasMore {
            LoadMoreRow(failed: pageFailed, loadingLabel: "Chargement de plus d'actualités") {
                await onAction(.loadMore)
            }
            .padding(.vertical, 8)
        }
    }

    private func releasedRow(_ item: ReleasedItem) -> some View {
        ReleasedRow(
            item: item,
            owned: taken.contains(item.id),
            wished: wished.contains(item.id),
            awaited: awaited.contains(item.id),
            onOpen: open(item),
            onAdd: { await onAction(.addReleased(item, $0, $1)) },
            onWish: { await onAction(.wishReleased(item)) },
            onAwait: { format in act(.awaitReleased(item, format)) }
        )
    }

    private func friendRow(_ move: FriendMove) -> some View {
        FeedEventRow(
            event: move.lead,
            others: move.others,
            wished: wished.contains(move.lead.bookId),
            awaited: awaited.contains(move.lead.bookId),
            onOpen: { act(.openFriendBook(move.lead)) },
            onAdd: { await onAction(.addFriendBook(move.lead, $0, $1)) },
            onWish: { await onAction(.wishFriendBook(move.lead)) },
            onAwait: { format in act(.awaitFriendBook(move.lead, format)) }
        )
        .task { await onAction(.prefetch((move.others.last ?? move.lead).id)) }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title2.weight(.bold))
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 4)
    }

    /// What a tap on a row opens: the author of their book, the narrator of
    /// theirs; a series' volume or an edition awaited opens nothing yet.
    private func open(_ item: ReleasedItem) -> (() -> Void)? {
        switch item {
        case let .release(release, _): release.author == nil ? nil : { act(.openAuthor(release)) }
        case let .narrator(news, _): { act(.openNarrator(news)) }
        }
    }
}

private struct NewsPagePreview: View {
    var events: [FeedEvent] = FeedEvent.previews + FeedEvent.sameStartPreviews
    var releases: [UpcomingRelease] = UpcomingRelease.previews
    var isLoading = false
    var errorMessage: String?

    private var feed: [NewsFeedSection] {
        NewsFeedLayout.feedSections(
            released: NewsFeedLayout.released(
                releases: UpcomingRelease.releasedPreviews,
                narrator: [.preview],
                format: nil
            ),
            events: events,
            format: nil,
            friendId: nil
        )
    }

    var body: some View {
        NavigationStack {
            NewsPage(
                feed: feed,
                calendar: ReleaseCalendar(releases: releases, now: .now),
                format: nil,
                pillFormats: NewsFeedLayout.pillFormats(in: feed, selected: nil),
                stories: NewsFeedLayout.stories(events: events, seenAt: .now.addingTimeInterval(-86400)),
                friendId: nil,
                hasMore: false,
                pageFailed: false,
                isLoading: isLoading,
                errorMessage: errorMessage,
                alertsSilenced: false,
                onAction: { _ in }
            )
        }
        .preferredColorScheme(.dark)
    }
}

#Preview("Actualités") { NewsPagePreview() }
#Preview("Sans amis") { NewsPagePreview(events: []) }
#Preview("Loading") { NewsPagePreview(events: [], releases: [], isLoading: true) }
#Preview("Failed") { NewsPagePreview(events: [], releases: [], errorMessage: "Le réseau est indisponible.") }
