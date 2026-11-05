import SwiftUI

/// Everything the series screen of the Library tab can ask for.
enum SeriesShelfAction {
    case openSeries(FollowedSeries)
    case selectFilter(SeriesShelfFilter)
    case follow(FollowedSeries)
    case refresh
}

/// The series, as the TV app sets out the shows one follows: "À suivre", the
/// next volume of each saga in progress; "Prochaines sorties", the volumes
/// announced, each drawn as the saga screen's release card, in a rail; then every saga as the home's cards, two by
/// row, under their filters, the last of which, "Non suivies", lists the
/// sagas no longer followed, greyed.
struct SeriesShelfPage: View {
    let upNext: [(series: FollowedSeries, volume: FollowedSeries.NextVolume)]
    let releases: [(series: FollowedSeries, volume: DiscoveredVolume)]
    let filters: [SeriesShelfFilter]
    let filter: SeriesShelfFilter
    let series: [FollowedSeries]
    let isLoading: Bool
    let errorMessage: String?
    let onAction: (SeriesShelfAction) -> Void

    @State private var releaseInView: String?

    private let columns = [GridItem(.flexible(), spacing: 13), GridItem(.flexible(), spacing: 13)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                if !upNext.isEmpty {
                    SeriesUpNextRail(upNext: upNext) { onAction(.openSeries($0)) }
                }
                if !releases.isEmpty {
                    VStack(alignment: .leading, spacing: SeriesReleaseCard.headerSpacing) {
                        RowHeader(title: "Prochaines sorties", style: .inline).padding(.horizontal, 20)
                        releaseRail
                    }
                }
                allSeries
            }
            .padding(.vertical, 8)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Séries")
        .navigationBarTitleDisplayMode(.large)
        .refreshable { onAction(.refresh) }
        .overlay {
            if series.isEmpty, upNext.isEmpty {
                if isLoading {
                    ProgressView()
                } else if let errorMessage {
                    EmptyState.failure("Séries indisponibles", message: errorMessage) { onAction(.refresh) }
                }
            }
        }
    }

    /// The release cards side by side, the next one showing at the edge; a
    /// lone card takes the full width. The dots say which one is in view.
    private var releaseRail: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(releases, id: \.series.id) { entry in
                        SeriesReleaseCard(
                            volume: entry.volume,
                            author: entry.series.author ?? entry.series.name,
                            isAudio: entry.series.isAudio,
                            language: entry.series.language
                        ) { onAction(.openSeries(entry.series)) }
                        .containerRelativeFrame(.horizontal) { width, _ in
                            SeriesReleaseCard.railWidth(width, count: releases.count)
                        }
                        .id(entry.series.id)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $releaseInView)
            if releases.count > 1 {
                HStack(spacing: 6) {
                    ForEach(releases, id: \.series.id) { entry in
                        Circle()
                            .fill(entry.series.id == (releaseInView ?? releases.first?.series.id)
                                ? Color.primary : Color.secondary.opacity(0.4))
                            .frame(width: 6, height: 6)
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder private var allSeries: some View {
        if !series.isEmpty || filter != .all {
            VStack(alignment: .leading, spacing: 14) {
                RowHeader(title: "Toutes les séries", style: .inline).padding(.horizontal, 20)
                if filters.count > 1 {
                    FilterPills(
                        pills: filters.map { FilterPills.Pill(id: $0.rawValue, label: $0.label) },
                        selected: filter.rawValue,
                        allLabel: nil
                    ) { id in onAction(.selectFilter(id.flatMap(SeriesShelfFilter.init(rawValue:)) ?? .all)) }
                }
                if filter == .notFollowed {
                    Text("Ces séries ne sont plus suivies : elles n'apparaissent ni dans « À suivre », ni dans les sorties, ni sur l'accueil. Leurs tomes restent dans la bibliothèque.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                }
                LazyVGrid(columns: columns, spacing: 13) {
                    ForEach(series) { saga in
                        SeriesShowCard(
                            series: saga.progress,
                            tag: tag(of: saga),
                            isCompact: true,
                            isSetAside: saga.isSetAside
                        ) {
                            onAction(.openSeries(saga))
                        }
                        .frame(height: 128)
                        .contextMenu {
                            if saga.isSetAside {
                                Button("Suivre à nouveau", systemImage: "bell") { onAction(.follow(saga)) }
                            }
                        }
                        .transition(.homeCard)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    /// Under "À compléter", how many volumes to add; elsewhere the next date.
    private func tag(of saga: FollowedSeries) -> String? {
        guard filter == .incomplete else { return saga.releaseTag }
        let missing = saga.missingCount
        return missing == 1
            ? String(localized: "1 tome à ajouter")
            : String(localized: "\(missing) tomes à ajouter")
    }

}

#if DEBUG
#Preview {
    let series = SeriesFixtures.followed
    NavigationStack {
        SeriesShelfPage(
            upNext: series.compactMap { saga in saga.nextVolume.map { (saga, $0) } },
            releases: series.compactMap { saga in saga.announced.map { (saga, $0) } },
            filters: SeriesShelfFilter.offered(for: series),
            filter: .all,
            series: series,
            isLoading: false,
            errorMessage: nil
        ) { _ in }
    }
}
#endif
