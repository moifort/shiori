import Charts
import SwiftUI

/// How many sessions GA4 counted each day, in the same columns as the costs:
/// the count above, the date below, two weeks at a time, opening on the last
/// counted day.
struct AdminDailySessionsChart: View {
    let days: [AdminMetrics.DailySessions]
    let daysInMonth: Int

    var body: some View {
        Chart(days) { day in
            BarMark(
                x: .value("Jour", AdminDailyChart.dayNumber(day.day)),
                y: .value("Sessions", day.sessions),
                width: .fixed(AdminDailyChart.barWidth)
            )
            .foregroundStyle(Color.blue)
            .cornerRadius(3)
            .annotation(position: .top, spacing: 2) {
                AdminDailyChart.valueLabel(day.sessions.formatted(.number))
            }
            .annotation(position: .bottom, spacing: 4) {
                AdminDailyChart.dayLabel(day.day)
            }
        }
        .modifier(
            AdminDailyChart.Layout(
                daysInMonth: daysInMonth,
                lastDay: days.last.map { AdminDailyChart.dayNumber($0.day) } ?? 1,
                peak: Double(days.map(\.sessions).max() ?? 0)
            )
        )
    }
}

#Preview {
    AdminDailySessionsChart(days: AdminMetrics.preview.sessions ?? [], daysInMonth: 31)
        .padding()
}
