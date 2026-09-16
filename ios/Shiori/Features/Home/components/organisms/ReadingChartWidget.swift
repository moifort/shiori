import Charts
import SwiftUI

/// Books read per year, or pages read per month of this year. Every bar carries
/// the same colour, the period still running included: a paler bar there read as
/// a defect rather than as a period not over yet.
struct ReadingChartWidget: View {
    enum Metric: String, CaseIterable, Identifiable {
        case books, pages
        var id: String { rawValue }

        var label: LocalizedStringKey {
            switch self {
            case .books: "Livres"
            case .pages: "Pages"
            }
        }
    }

    let currentYear: Int
    let booksPerYear: [Dashboard.YearCount]
    let pagesPerMonth: [Dashboard.MonthPages]
    @State private var metric: Metric = .books

    var body: some View {
        WidgetCard(title: metric == .books ? "Livres lus" : "Pages lues") {
            Picker("Mesure", selection: $metric.animation(.snappy)) {
                ForEach(Metric.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 150)
            .accessibilityIdentifier("home-chart-metric")
        } content: {
            VStack(alignment: .leading, spacing: 8) {
                total
                chart.frame(height: 150)
            }
        }
        .accessibilityIdentifier("home-chart")
    }

    private var total: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            switch metric {
            case .books:
                Text(booksThisYear, format: .number)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(DashboardPalette.books)
                Text("livres en \(String(currentYear))")
            case .pages:
                Text(pagesThisYear, format: .number)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(DashboardPalette.pages)
                Text("pages en \(String(currentYear))")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .contentTransition(.numericText())
    }

    /// A chart of zeros gets a floor of one on its axis, so the first book of the
    /// year has somewhere to grow rather than a flat line with no scale.
    @ViewBuilder
    private var chart: some View {
        switch metric {
        case .books:
            Chart(booksPerYear) { entry in
                BarMark(x: .value("Année", String(entry.year)), y: .value("Livres", entry.count))
                    .foregroundStyle(DashboardPalette.books)
                    .cornerRadius(4)
            }
            .chartYScale(domain: 0...max(1, booksPerYear.map(\.count).max() ?? 0))
            // Years keep their labels and lose their gridlines: six dashed
            // verticals between six bars is more furniture than reading.
            .chartXAxis { AxisMarks { AxisValueLabel() } }
            .chartYAxis { AxisMarks(position: .leading) }
        case .pages:
            // Numeric months rather than month letters: J, J and M, M would collide
            // as category labels.
            Chart(pagesPerMonth) { entry in
                BarMark(
                    x: .value("Mois", entry.month),
                    y: .value("Pages", entry.pages),
                    width: .fixed(14)
                )
                .foregroundStyle(DashboardPalette.pages)
                .cornerRadius(3)
            }
            .chartXScale(domain: 0.5...12.5)
            .chartYScale(domain: 0...max(1, pagesPerMonth.map(\.pages).max() ?? 0))
            .chartXAxis {
                AxisMarks(values: Array(1...12)) { value in
                    // An explicit anchor: left to its default, a label built from
                    // a closure sits a few points right of its own column.
                    AxisValueLabel(anchor: .top) {
                        if let month = value.as(Int.self) {
                            Text(Calendar.current.veryShortStandaloneMonthSymbols[month - 1])
                        }
                    }
                }
            }
            .chartYAxis { AxisMarks(position: .leading) }
        }
    }

    private var booksThisYear: Int { booksPerYear.first { $0.year == currentYear }?.count ?? 0 }
    private var pagesThisYear: Int { pagesPerMonth.reduce(0) { $0 + $1.pages } }
}

#Preview {
    ReadingChartWidget(
        currentYear: 2026,
        booksPerYear: [.init(year: 2023, count: 9), .init(year: 2024, count: 21), .init(year: 2025, count: 16), .init(year: 2026, count: 18)],
        pagesPerMonth: (1...12).map { .init(month: $0, pages: $0 < 10 ? $0 * 90 : 0) }
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("First book") {
    ReadingChartWidget(
        currentYear: 2026,
        booksPerYear: (2021...2026).map { .init(year: $0, count: 0) },
        pagesPerMonth: (1...12).map { .init(month: $0, pages: 0) }
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
