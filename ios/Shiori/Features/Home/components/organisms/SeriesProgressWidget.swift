import SwiftUI

struct SeriesProgressWidget: View {
    let series: [Dashboard.SeriesProgress]
    let onHeaderTapped: () -> Void

    var body: some View {
        WidgetCard(title: "Séries en cours", action: onHeaderTapped) {
            if series.isEmpty {
                WidgetEmptyMessage(text: "Aucune série en cours.", placeholder: .rings)
            }
            VStack(spacing: 14) {
                ForEach(series) { entry in
                    NavigationLink(value: HomeView.Destination.series(entry.id)) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                SagaName(name: entry.name, isAudio: entry.isAudio)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(1)
                                Spacer()
                                // What ranks the saga here: the heart, else
                                // the stars.
                                OpinionMark(rating: entry.rating, isFavorite: entry.favorite)
                                Text("\(entry.readCount)/\(entry.totalCount)")
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            ProgressView(value: Double(entry.readCount), total: Double(max(1, entry.totalCount)))
                                .tint(DashboardPalette.series)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .accessibilityIdentifier("home-series")
    }
}
