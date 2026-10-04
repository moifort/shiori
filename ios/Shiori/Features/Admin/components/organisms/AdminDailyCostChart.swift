import Charts
import SwiftUI

/// What the bill says each day of the month cost, Gemini stacked on the rest of
/// the project. The axis spans the whole month, so the days still to come read
/// as empty room rather than the chart stretching what is known. The bill runs
/// about a day behind: today is never drawn.
struct AdminDailyCostChart: View {
    let days: [AdminMetrics.DailyCost]
    let monthStart: Date
    let monthEnd: Date

    private struct Bar: Identifiable {
        let day: Date
        let line: String
        let eur: Double
        var id: String { "\(day.timeIntervalSince1970)-\(line)" }
    }

    private static let gemini = String(localized: "Gemini")
    private static let infra = String(localized: "Infra")

    private var bars: [Bar] {
        days.flatMap { day in
            [
                Bar(day: day.day, line: Self.gemini, eur: day.geminiEur),
                Bar(day: day.day, line: Self.infra, eur: day.infraEur),
            ]
        }
    }

    var body: some View {
        Chart(bars) { bar in
            BarMark(
                x: .value("Jour", bar.day, unit: .day, calendar: AdminMetrics.utc),
                y: .value("Coût", bar.eur)
            )
            .foregroundStyle(by: .value("Poste", bar.line))
        }
        .chartForegroundStyleScale([Self.gemini: Color.purple, Self.infra: Color.gray])
        .chartXScale(domain: monthStart...endOfLastDay)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7, calendar: AdminMetrics.utc)) { _ in
                AxisGridLine()
                AxisValueLabel(format: AdminFormat.dayMonth)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let eur = value.as(Double.self) {
                        Text(eur.formatted(.currency(code: "EUR").precision(.fractionLength(0))))
                    }
                }
            }
        }
        .chartLegend(position: .top, alignment: .leading)
        .frame(height: 180)
    }

    /// The axis ends at the close of the last day, so its bar has room.
    private var endOfLastDay: Date {
        AdminMetrics.utc.date(byAdding: .day, value: 1, to: monthEnd) ?? monthEnd
    }
}

#Preview {
    let metrics = AdminMetrics.preview
    AdminDailyCostChart(
        days: metrics.costs?.days ?? [], monthStart: metrics.month, monthEnd: metrics.monthEnd
    )
    .padding()
}
