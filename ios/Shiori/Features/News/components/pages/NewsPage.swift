import SwiftUI

/// Everything the Actualités page can ask for.
enum NewsAction {
    case selectFormat(BookFormat?)
    case openFriendBook(FeedEvent)
    case take(FeedEvent, BookFormat)
    case openAuthor(UpcomingRelease)
    case openWinner(AwardWinner)
    case addWinner(AwardWinner)
    case dismissWinner
    case openNarrator(NarratorNews)
    case addNarrator(NarratorNews)
    case openUpcoming
    case openAlerts
    case prefetch(String)
    case loadMore
    case refresh
}

/// The Actualités page, pure: the format pills, the friends' feed by day with
/// the author's and the award's cards among it, and "Prochainement" with its
/// calendar. The pages a tap opens are the screen's.
struct NewsPage: View {
    let sections: [FeedSection]
    let calendar: ReleaseCalendar
    let format: BookFormat?
    @Binding var horizon: ReleaseHorizon
    @Binding var selectedDay: Int?
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

    private var isEmpty: Bool { sections.allSatisfy(\.items.isEmpty) }

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
        if let errorMessage, isEmpty, calendar.releases.isEmpty, !isLoading {
            EmptyState.failure("Actualités indisponibles", message: errorMessage) {
                await onAction(.refresh)
            }
        } else if isLoading, isEmpty, calendar.releases.isEmpty {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    FilterPills(
                        pills: NewsFeedLayout.pillFormats.map { .init(id: $0.rawValue, label: $0.pillLabel) },
                        selected: format?.rawValue
                    ) { id in
                        act(.selectFormat(id.flatMap(BookFormat.init(rawValue:))))
                    }
                    .padding(.bottom, 4)
                    feed
                    ReleaseCalendarSection(
                        calendar: calendar,
                        horizon: $horizon,
                        selectedDay: $selectedDay,
                        onOpenAll: { act(.openUpcoming) },
                        onOpen: { act(.openAuthor($0)) }
                    )
                    .padding(.top, 30)
                    .padding(.bottom, 24)
                }
            }
            .refreshable { await onAction(.refresh) }
        }
    }

    @ViewBuilder
    private var feed: some View {
        if isEmpty {
            EmptyState(
                systemImage: "newspaper",
                title: "Rien de neuf",
                message: "Ce que vos amis lisent, terminent ou adorent apparaît ici."
            )
            .frame(minHeight: 260)
        } else {
            ForEach(sections) { section in
                if !section.items.isEmpty {
                    Text(section.title)
                        .font(.title2.weight(.bold))
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 6)
                    ForEach(section.items) { item in
                        row(item)
                            .task { if case let .friend(event) = item { await onAction(.prefetch(event.id)) } }
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
    }

    @ViewBuilder
    private func row(_ item: FeedItem) -> some View {
        switch item {
        case let .friend(event):
            FeedEventRow(
                event: event,
                onOpen: { act(.openFriendBook(event)) },
                onTake: { await onAction(.take(event, $0)) }
            )
        case let .narrator(news):
            NarratorEventRow(news: news, onOpen: { act(.openNarrator(news)) }, onAdd: { await onAction(.addNarrator(news)) })
        case let .author(release):
            AuthorAnnouncementCard(release: release) { act(.openAuthor(release)) }
        case let .award(winner):
            AwardNewsCard(
                winner: winner,
                onOpen: { act(.openWinner(winner)) },
                onAdd: { await onAction(.addWinner(winner)) },
                onDismiss: { act(.dismissWinner) }
            )
        }
    }
}

private struct NewsPagePreview: View {
    var events: [FeedEvent] = FeedEvent.previews
    var releases: [UpcomingRelease] = UpcomingRelease.previews
    var isLoading = false
    var errorMessage: String?
    @State private var horizon = ReleaseHorizon.month
    @State private var day: Int?

    var body: some View {
        NavigationStack {
            NewsPage(
                sections: NewsFeedLayout.sections(
                    events: events,
                    narrator: events.isEmpty ? [] : [.preview],
                    spotlight: releases.first,
                    award: events.isEmpty ? nil : .newsPreview
                ),
                calendar: ReleaseCalendar(releases: releases, now: .now),
                format: nil,
                horizon: $horizon,
                selectedDay: $day,
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

#Preview("Filled") { NewsPagePreview() }
#Preview("Nothing yet") { NewsPagePreview(events: [], releases: []) }
#Preview("Loading") { NewsPagePreview(events: [], releases: [], isLoading: true) }
#Preview("Failed") { NewsPagePreview(events: [], releases: [], errorMessage: "Le réseau est indisponible.") }
