import SwiftUI

/// Everything the Actualités page can ask for.
enum NewsAction {
    case selectTab(NewsTab)
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
    case openNarrator(NarratorNews)
    case invite
    case openAlerts
    case prefetch(String)
    case loadMore
    case refresh
}

/// The Actualités page, pure, cut in two by who speaks. Sorties: the format
/// pills, what came out in the last thirty days among the series, authors,
/// narrators and awaited editions the reader follows under journal periods,
/// the book first; then "À venir" and its calendar. Amis: the friends as
/// stories, then their moves under journal periods as notifications, the same
/// move by several of them on one line. Every row ends on the "…" that takes
/// the book, wishes for it or awaits its recording. The pages a tap opens are
/// the screen's.
struct NewsPage: View {
    let tab: NewsTab
    let friendsHaveNews: Bool
    let released: [ReleasedSection]
    /// The rows' books just taken, wished for or awaited: a friend's by its
    /// book id, a release by its row id.
    var taken: Set<String> = []
    var wished: Set<String> = []
    var awaited: Set<String> = []
    let calendar: ReleaseCalendar
    let format: BookFormat?
    let stories: [FriendStory]
    let friendSections: [FriendSection]
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

    private var isEmpty: Bool { released.isEmpty && calendar.releases.isEmpty && stories.isEmpty }

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
                    NewsTabPicker(selected: tab, friendsHaveNews: friendsHaveNews) { act(.selectTab($0)) }
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                    switch tab {
                    case .releases: releases
                    case .friends: friends
                    }
                }
                .padding(.bottom, 24)
            }
            .refreshable { await onAction(.refresh) }
        }
    }

    // MARK: - Sorties

    @ViewBuilder
    private var releases: some View {
        FilterPills(
            pills: NewsFeedLayout.pillFormats.map { .init(id: $0.rawValue, label: $0.pillLabel) },
            selected: format?.rawValue
        ) { id in
            act(.selectFormat(id.flatMap(BookFormat.init(rawValue:))))
        }
        .padding(.top, 14)
        if released.isEmpty {
            Text("Rien n'est sorti ces 30 derniers jours.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 8)
                .accessibilityIdentifier("news-released-empty")
        } else {
            ForEach(released) { section in
                sectionTitle(section.title)
                ForEach(section.items) { item in
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
            }
        }
        ReleaseCalendarSection(calendar: calendar, onOpen: { act(.openAuthor($0)) })
            .padding(.top, 30)
    }

    // MARK: - Amis

    @ViewBuilder
    private var friends: some View {
        if stories.isEmpty {
            noFriends
        } else {
            FriendStoriesRail(
                stories: stories,
                selected: friendId,
                onSelect: { act(.selectFriend($0)) },
                onInvite: { await onAction(.invite) }
            )
            .padding(.top, 18)
            ForEach(friendSections) { section in
                sectionTitle(section.title)
                ForEach(section.moves) { move in
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
            }
            if hasMore {
                LoadMoreRow(failed: pageFailed, loadingLabel: "Chargement de plus d'actualités") {
                    await onAction(.loadMore)
                }
                .padding(.vertical, 8)
            }
        }
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

    /// Nobody shares their shelves yet: the way to change that, not a blank tab.
    private var noFriends: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.2")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("Aucun ami pour l'instant")
                .font(.headline)
            Text("Partagez votre bibliothèque pour voir ce que vos amis lisent.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            AsyncButton { await onAction(.invite) } label: {
                Text("Inviter")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .frame(height: 36)
                    .background(Color.primary, in: .capsule)
                    .foregroundStyle(Color(.systemBackground))
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
            .accessibilityIdentifier("news-invite-empty")
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
        .padding(.top, 72)
    }
}

private struct NewsPagePreview: View {
    @State var tab: NewsTab = .releases
    var events: [FeedEvent] = FeedEvent.previews + FeedEvent.sameStartPreviews
    var releases: [UpcomingRelease] = UpcomingRelease.previews
    var isLoading = false
    var errorMessage: String?

    var body: some View {
        NavigationStack {
            NewsPage(
                tab: tab,
                friendsHaveNews: tab == .releases && !events.isEmpty,
                released: NewsFeedLayout.releasedSections(NewsFeedLayout.released(
                    releases: UpcomingRelease.releasedPreviews,
                    narrator: [.preview],
                    format: nil
                )),
                calendar: ReleaseCalendar(releases: releases, now: .now),
                format: nil,
                stories: NewsFeedLayout.stories(events: events, seenAt: .now.addingTimeInterval(-86400)),
                friendSections: NewsFeedLayout.friendSections(events: events),
                friendId: nil,
                hasMore: false,
                pageFailed: false,
                isLoading: isLoading,
                errorMessage: errorMessage,
                alertsSilenced: false,
                onAction: { action in
                    if case let .selectTab(next) = action { tab = next }
                }
            )
        }
        .preferredColorScheme(.dark)
    }
}

#Preview("Sorties") { NewsPagePreview() }
#Preview("Amis") { NewsPagePreview(tab: .friends) }
#Preview("Amis, vide") { NewsPagePreview(tab: .friends, events: []) }
#Preview("Loading") { NewsPagePreview(events: [], releases: [], isLoading: true) }
#Preview("Failed") { NewsPagePreview(events: [], releases: [], errorMessage: "Le réseau est indisponible.") }
