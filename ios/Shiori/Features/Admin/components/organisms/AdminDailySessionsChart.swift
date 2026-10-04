import Charts
import SwiftUI

/// How many sessions GA4 counted each day of the month, over the same
/// whole-month axis as the costs, so the two charts line up day for day.
struct AdminDailySessionsChart: View {
    let days: [AdminMetrics.DailySessions]
    let monthStart: Date
    let monthEnd: Date

    var body: some View {
        Chart(days) { day in
            BarMark(
                x: .value("Jour", day.day, unit: .day, calendar: AdminMetrics.utc),
                y: .value("Sessions", day.sessions)
            )
            .foregroundStyle(Color.blue)
        }
        .chartXScale(domain: monthStart...endOfLastDay)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7, calendar: AdminMetrics.utc)) { _ in
                AxisGridLine()
                AxisValueLabel(format: AdminFormat.dayMonth)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .frame(height: 160)
    }

    private var endOfLastDay: Date {
        AdminMetrics.utc.date(byAdding: .day, value: 1, to: monthEnd) ?? monthEnd
    }
}

#Preview {
    let metrics = AdminMetrics.preview
    AdminDailySessionsChart(
        days: metrics.sessions ?? [], monthStart: metrics.month, monthEnd: metrics.monthEnd
    )
    .padding()
}
