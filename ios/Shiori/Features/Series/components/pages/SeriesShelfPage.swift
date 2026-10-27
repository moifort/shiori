import SwiftUI

/// Everything the series screen of the Library tab can ask for.
enum SeriesShelfAction {
    case openSeries(FollowedSeries)
    case selectFilter(SeriesShelfFilter)
    case openSetAside
    case refresh
}

/// The series, as the TV app sets out the shows one follows: "À suivre", the
/// next volume of each saga in progress; "Prochaines sorties", the volumes
/// announced, each drawn as the saga screen's release card, in a rail; then every saga as the home's cards, two by
/// row, under their filters — and, at the foot, the sagas set aside.
struct SeriesShelfPage: View {
    let upNext: [(series: FollowedSeries, volume: FollowedSeries.NextVolume)]
    let releases: [(series: FollowedSeries, volume: DiscoveredVolume)]
    let filters: [SeriesShelfFilter]
    let filter: SeriesShelfFilter
    let series: [FollowedSeries]
    let hasSetAside: Bool
    let isLoading: Bool
    let errorMessage: String?
    let onAction: (SeriesShelfAction) -> Void

    @State private var releaseInView: String?

    private let columns = [GridItem(.flexible(), spacing: 13), GridItem(.flexible(), spacing: 13)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                if !upNext.isEmpty, filter == .all {
                    VStack(alignment: .leading, spacing: 12) {
                        RowHeader(title: "À suivre", style: .inline).padding(.horizontal, 20)
                        PosterRow(items: upNext.map(upNextItem)) { _ in }
                            .contentMargins(.horizontal, 20, for: .scrollContent)
                    }
                }
                if !releases.isEmpty, filter == .all {
                    VStack(alignment: .leading, spacing: 12) {
                        RowHeader(title: "Prochaines sorties", style: .inline).padding(.horizontal, 20)
                        releaseRail
                    }
                }
                allSeries
                if hasSetAside, filter == .all {
                    setAsideRow
                }
            }
            .padding(.vertical, 8)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Séries")
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

    private func upNextItem(_ entry: (series: FollowedSeries, volume: FollowedSeries.NextVolume)) -> PosterRow.Item {
        let open = { onAction(.openSeries(entry.series)) }
        switch entry.volume {
        case let .owned(book):
            let caption = book.series?.volume.map { String(localized: "Tome \($0)") } ?? book.title
            return PosterRow.Item(
                book: book,
                label: PosterLabel(caption: caption, marksReading: book.status == .reading),
                open: open
            )
        case let .missing(number, title, coverURL):
            let book = Book(
                id: "next-\(entry.series.id)",
                title: title,
                authors: entry.series.author.map { [$0] } ?? [],
                format: entry.series.isAudio ? .audiobook : .book,
                language: entry.series.language,
                coverURL: coverURL,
                status: .toRead
            )
            return PosterRow.Item(
                book: book,
                caption: number.map { String(localized: "Tome \($0)") } ?? title,
                open: open
            )
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
                            isAudio: entry.series.isAudio
                        ) { onAction(.openSeries(entry.series)) }
                        .containerRelativeFrame(.horizontal) { width, _ in
                            releases.count > 1 ? width - 50 : width - 40
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
                LazyVGrid(columns: columns, spacing: 13) {
                    ForEach(series) { saga in
                        SeriesShowCard(series: saga.progress, tag: tag(of: saga), isCompact: true) {
                            onAction(.openSeries(saga))
                        }
                        .frame(height: 128)
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

    private var setAsideRow: some View {
        Button { onAction(.openSetAside) } label: {
            HStack(spacing: 12) {
                Image(systemName: "nosign")
                    .foregroundStyle(.secondary)
                    .frame(width: 26)
                Text("Mises de côté")
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .frame(height: 50)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
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
            hasSetAside: true,
            isLoading: false,
            errorMessage: nil
        ) { _ in }
    }
}
#endif
