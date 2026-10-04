import Charts
import SwiftUI

/// What the bill says each day cost, drawn like the home screen's reading chart:
/// one column per day, Gemini stacked under the rest of the project, the day's
/// total written above its column and its date below, no axis and no grid.
///
/// A month of priced columns does not fit the width of a phone — "2,05" needs
/// more room than a thirty-first of the card — so the chart scrolls sideways,
/// two weeks at a time, opening on the last billed day. The bill runs about a
/// day behind: today is never drawn.
struct AdminDailyCostChart: View {
    let days: [AdminMetrics.DailyCost]
    let daysInMonth: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                legend("Gemini", color: .purple)
                legend("Infra", color: .gray)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Chart(days) { day in
                BarMark(
                    x: .value("Jour", AdminDailyChart.dayNumber(day.day)),
                    y: .value("Gemini", day.geminiEur),
                    width: .fixed(AdminDailyChart.barWidth)
                )
                .foregroundStyle(Color.purple)
                .annotation(position: .bottom, spacing: 4) {
                    AdminDailyChart.dayLabel(day.day)
                }
                BarMark(
                    x: .value("Jour", AdminDailyChart.dayNumber(day.day)),
                    y: .value("Infra", day.infraEur),
                    width: .fixed(AdminDailyChart.barWidth)
                )
                .foregroundStyle(Color.gray)
                .annotation(position: .top, spacing: 2) {
                    AdminDailyChart.valueLabel(
                        (day.geminiEur + day.infraEur).formatted(.number.precision(.fractionLength(2)))
                    )
                }
            }
            .modifier(
                AdminDailyChart.Layout(
                    daysInMonth: daysInMonth,
                    lastDay: days.last.map { AdminDailyChart.dayNumber($0.day) } ?? 1,
                    peak: days.map { $0.geminiEur + $0.infraEur }.max() ?? 0
                )
            )
        }
    }

    private func legend(_ title: LocalizedStringKey, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title)
        }
    }
}

/// What the two daily charts of the admin screen share: the home chart's look,
/// and the sideways scroll a month of labelled columns needs.
enum AdminDailyChart {
    static let barWidth: CGFloat = 14
    /// Two weeks on screen: room for a price above each column.
    static let visibleDays = 14

    static func dayNumber(_ day: Date) -> Int {
        AdminMetrics.utc.component(.day, from: day)
    }

    static func dayLabel(_ day: Date) -> some View {
        Text(day.formatted(AdminFormat.dayOfMonth))
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }

    /// Nine points, as on the home chart: the figure has to fit between its
    /// neighbours.
    static func valueLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, design: .rounded))
            .foregroundStyle(.secondary)
            .fixedSize()
    }

    /// Whole month on the axis, two weeks visible, opening on the last known
    /// day; headroom above the tallest column for its label; no axis, no grid,
    /// and a strip under the plot for the dates.
    struct Layout: ViewModifier {
        let daysInMonth: Int
        let lastDay: Int
        let peak: Double

        func body(content: Content) -> some View {
            content
                .chartXScale(domain: 0.5...(Double(daysInMonth) + 0.5))
                .chartYScale(domain: 0...max(peak * 1.25, 1))
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartScrollableAxes(.horizontal)
                .chartXVisibleDomain(length: AdminDailyChart.visibleDays)
                .chartScrollPosition(
                    initialX: Double(max(1, lastDay - AdminDailyChart.visibleDays + 1)) - 0.5
                )
                .chartPlotStyle { plot in plot.padding(.bottom, 16) }
                .frame(height: 150)
        }
    }
}

#Preview {
    AdminDailyCostChart(days: AdminMetrics.preview.costs?.days ?? [], daysInMonth: 31)
        .padding()
}
