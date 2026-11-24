import SwiftUI

/// Everything the series screen of the Library tab can ask for.
enum SeriesShelfAction {
    case openSeries(FollowedSeries)
    case openBook(Book)
    /// A volume the reader lacks, on its own page.
    case openVolume(DiscoveryVolume)
    case selectFilter(SeriesShelfFilter)
    /// A friend's sagas: a format pill, and the status menu in the corner.
    case selectFormat(BookFormat?)
    case selectStatus(SeriesStatusFilter)
    case follow(FollowedSeries)
    case refresh
}

/// The series, as the TV app sets out the shows one follows: "Séries à continuer", the
/// next volume of each saga in progress; "Prochaines sorties", the volumes
/// announced, each drawn as the saga screen's release card, in a rail; then every saga as the home's cards, two by
/// row, under their filters, the last of which, "Non suivies", lists the
/// sagas no longer followed, greyed.
///
/// A friend's "Séries" is this same page with the cards of "Toutes les
/// séries" alone, untitled, over their sagas, under the filters of "Livres":
/// the format pills, and the status menu in the corner.
struct SeriesShelfPage: View {
    let upNext: [(series: FollowedSeries, volume: FollowedSeries.NextVolume)]
    let releases: [(series: FollowedSeries, volume: DiscoveredVolume)]
    let filters: [SeriesShelfFilter]
    let filter: SeriesShelfFilter
    let series: [FollowedSeries]
    let isLoading: Bool
    let errorMessage: String?
    /// A friend's sagas: the status menu offered in the corner, which puts the
    /// format pills in place of the filters'. Empty on the reader's own.
    var statuses: [SeriesStatusFilter] = []
    var selectedStatus: SeriesStatusFilter = .all
    var formats: [BookFormat] = []
    var selectedFormat: BookFormat?
    let onAction: (SeriesShelfAction) -> Void

    @State private var releaseInView: String?

    private let columns = [GridItem(.flexible(), spacing: 13), GridItem(.flexible(), spacing: 13)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                if !upNext.isEmpty {
                    SeriesUpNextRail(upNext: upNext) { onAction(.open($0)) }
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
        .refreshable { onAction(.refresh) }
        .toolbar {
            if !statuses.isEmpty {
                ToolbarItem(placement: .primaryAction) { statusMenu }
            }
        }
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
                        ) {
                            // The volume's page, as the card says: its saga is
                            // a tap away from there.
                            onAction(.openVolume(DiscoveryVolume(
                                saga: SagaDiscovery(
                                    series: entry.series,
                                    releases: SagaReleases(watched: true, next: entry.volume)
                                ),
                                volume: entry.volume
                            )))
                        }
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

    /// The status menu of a friend's sagas, drawn as the one over "Livres".
    private var statusMenu: some View {
        Menu {
            Picker("Statut", selection: Binding(
                get: { selectedStatus },
                set: { onAction(.selectStatus($0)) }
            )) {
                ForEach(statuses) { status in
                    Label(status.label, systemImage: status.symbol).tag(status)
                }
            }
        } label: {
            ShelfFilterLabel(symbol: selectedStatus.symbol, title: selectedStatus.label)
        }
        .accessibilityIdentifier("friend-series-status-filter")
    }

    @ViewBuilder private var allSeries: some View {
        if !series.isEmpty || filter != .all || selectedStatus != .all || selectedFormat != nil {
            VStack(alignment: .leading, spacing: 14) {
                // A friend's page is this list alone: no title over it.
                if statuses.isEmpty {
                    RowHeader(title: "Toutes les séries", style: .inline).padding(.horizontal, 20)
                }
                if !statuses.isEmpty {
                    if formats.count > 1 {
                        FilterPills(
                            pills: formats.map { FilterPills.Pill(id: $0.rawValue, label: $0.shelfLabel) },
                            selected: selectedFormat?.rawValue
                        ) { onAction(.selectFormat($0.flatMap(BookFormat.init(rawValue:)))) }
                    }
                } else if filters.count > 1 {
                    FilterPills(
                        pills: filters.map { FilterPills.Pill(id: $0.rawValue, label: $0.label) },
                        selected: filter.rawValue,
                        allLabel: nil
                    ) { id in onAction(.selectFilter(id.flatMap(SeriesShelfFilter.init(rawValue:)) ?? .all)) }
                }
                if filter == .notFollowed {
                    Text("Ces séries ne sont plus suivies : elles n'apparaissent ni dans « Séries à continuer », ni dans les sorties, ni sur l'accueil. Leurs tomes restent dans la bibliothèque.")
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
            upNext: series.upNext,
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
