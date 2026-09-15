import SwiftUI

/// This year against the same span of last year, with the Fitness app's arrows.
/// Without last year there is no arrow, only this year's figure.
struct TrendsWidget: View {
    let pagesPerDay: Dashboard.Trend
    let daysToFinish: Dashboard.Trend

    var body: some View {
        WidgetCard(title: "Tendances") {
            Text("vs \(String(Calendar.current.component(.year, from: .now) - 1))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } content: {
            VStack(alignment: .leading, spacing: 14) {
                if pagesPerDay.current == nil, daysToFinish.current == nil {
                    WidgetEmptyMessage(text: "Terminez un livre cette année pour voir vos tendances.")
                }
                if let pages = pagesPerDay.current {
                    row(
                        label: "Pages par jour",
                        value: String(localized: "\(pages) p/j"),
                        previous: pagesPerDay.previous.map { String(localized: "\($0) p/j") },
                        direction: pagesPerDay.direction,
                        color: DashboardPalette.pages
                    )
                }
                if let days = daysToFinish.current {
                    row(
                        label: "Durée pour finir un livre",
                        value: String(localized: "\(days) jours"),
                        previous: daysToFinish.previous.map { String(localized: "\($0) jours") },
                        direction: daysToFinish.direction,
                        color: DashboardPalette.duration
                    )
                }
            }
        }
        .accessibilityIdentifier("home-trends")
    }

    private func row(
        label: LocalizedStringKey,
        value: String,
        previous: String?,
        direction: Dashboard.Trend.Direction?,
        color: Color
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.18))
                Image(systemName: symbol(for: direction))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(color)
            }
            .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.subheadline).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(value)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(color)
                    if let previous {
                        Text(previous).font(.footnote).foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private func symbol(for direction: Dashboard.Trend.Direction?) -> String {
        switch direction {
        case .up: "arrow.up"
        case .down: "arrow.down"
        case nil: "equal"
        }
    }
}

#Preview {
    TrendsWidget(
        pagesPerDay: .init(current: 24, previous: 18),
        daysToFinish: .init(current: 11, previous: 14)
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
