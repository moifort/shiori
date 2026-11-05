import SwiftUI

/// "À venir" at the head of Actualités, as the Series tab sets out its
/// "Prochaines sorties": every release dated to a month or a day, each drawn
/// as the saga screen's release card, side by side, the next one showing at the
/// edge; a lone card takes the full width. The dots say which one is in view.
/// The title opens the full list, the editions awaited that nothing announced
/// yet included.
struct UpcomingRail: View {
    let releases: [UpcomingRelease]
    let onOpenList: () -> Void
    let onOpen: (UpcomingRelease) -> Void

    @State private var inView: String?

    var body: some View {
        VStack(alignment: .leading, spacing: SeriesReleaseCard.headerSpacing) {
            RowHeader(title: "À venir", style: .inline, action: onOpenList)
                .padding(.horizontal, 20)
                .accessibilityIdentifier("news-upcoming-header")
            if !releases.isEmpty {
                rail
            }
        }
    }

    private var rail: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(releases) { release in
                        SeriesReleaseCard(
                            volume: DiscoveredVolume(
                                number: release.volume ?? 0,
                                title: release.shownTitle,
                                date: release.date,
                                isbn13: nil,
                                coverURL: release.coverURL
                            ),
                            author: release.authors.first ?? "",
                            isAudio: release.format == .audiobook,
                            place: release.cardPlace,
                            language: release.language,
                            isAwaited: release.source == .awaited
                        ) { onOpen(release) }
                        .containerRelativeFrame(.horizontal) { width, _ in
                            releases.count > 1 ? width - 50 : width - 40
                        }
                        .id(release.id)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $inView)
            if releases.count > 1 {
                HStack(spacing: 6) {
                    ForEach(releases) { release in
                        Circle()
                            .fill(release.id == (inView ?? releases.first?.id)
                                ? Color.primary : Color.secondary.opacity(0.4))
                            .frame(width: 6, height: 6)
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
            }
        }
    }
}

#Preview("Upcoming rail") {
    NavigationStack {
        ScrollView {
            UpcomingRail(
                releases: ReleaseCalendar(releases: UpcomingRelease.previews, now: .now).dated,
                onOpenList: {},
                onOpen: { _ in }
            )
        }
    }
    .preferredColorScheme(.dark)
}
