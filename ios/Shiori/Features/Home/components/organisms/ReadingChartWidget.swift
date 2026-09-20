import Charts
import SwiftUI

/// Books read per year, or pages read per month of this year. Every bar carries
/// the same colour, the period still running included: a paler bar there read as
/// a defect rather than as a period not over yet.
///
/// The chart is kept to its bars: no value axis, no gridlines, no frame. The
/// figure that matters is spelled out above it, so an axis would only repeat a
/// number already written in full; what the bars are for is the shape of the
/// years, which reads better small and unfurnished. Monthly bars carry their own
/// count on top, which reads a single month off without a scale to measure against.
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
    /// Pages open the card rather than books: twelve monthly bars fill its
    /// width where six yearly ones leave it mostly empty, and the running
    /// year is the figure a reader comes to the dashboard for.
    @State private var metric: Metric = .pages

    var body: some View {
        WidgetCard(title: metric == .books ? "Livres lus" : "Pages lues") {
            Picker("Mesure", selection: $metric.animation(.snappy)) {
                ForEach(Metric.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 150)
            .accessibilityIdentifier("home-chart-metric")
        } content: {
            VStack(alignment: .leading, spacing: 10) {
                total
                chart.frame(height: 84)
            }
        }
        .accessibilityIdentifier("home-chart")
    }

    private var total: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            switch metric {
            case .books:
                Text(booksThisYear, format: .number)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(DashboardPalette.books)
                Text("livres en \(String(currentYear))")
            case .pages:
                Text(pagesThisYear, format: .number)
                    .font(.system(.title, design: .rounded, weight: .bold))
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
                BarMark(
                    x: .value("Année", String(entry.year)),
                    y: .value("Livres", entry.count),
                    width: .fixed(14)
                )
                .foregroundStyle(DashboardPalette.books)
                .cornerRadius(3)
            }
            .chartYScale(domain: 0...max(1, booksPerYear.map(\.count).max() ?? 0))
            .chartXAxis { AxisMarks { periodLabel(Text(yearLabel(for: $0))) } }
            .chartYAxis(.hidden)
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
                .annotation(position: .top, spacing: 2) { pagesLabel(entry.pages) }
            }
            .chartXScale(domain: 0.5...12.5)
            .chartYScale(domain: 0...pagesScaleMax)
            .chartXAxis {
                AxisMarks(values: Array(1...12)) { value in
                    periodLabel(Text(monthLabel(for: value)))
                }
            }
            .chartYAxis(.hidden)
        }
    }

    /// Its count above each monthly bar, an empty month left bare rather than
    /// labelled zero. Nine points and no larger: twelve columns share the width of
    /// the card, and a four-figure month has to fit between its neighbours.
    @ViewBuilder
    private func pagesLabel(_ pages: Int) -> some View {
        if pages > 0 {
            Text(pages, format: .number)
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(.tertiary)
        }
    }

    /// Headroom above the tallest bar for the label it now carries, which the
    /// chart would otherwise clip against its top edge.
    private var pagesScaleMax: Int {
        max(1, Int(Double(pagesPerMonth.map(\.pages).max() ?? 0) * 1.2))
    }

    /// An explicit anchor: left to its default, a label built from a closure sits
    /// a few points right of its own column.
    private func periodLabel(_ text: Text) -> some AxisMark {
        AxisValueLabel(anchor: .top) {
            text.font(.caption2).foregroundStyle(.tertiary)
        }
    }

    private func yearLabel(for value: AxisValue) -> String { value.as(String.self) ?? "" }

    private func monthLabel(for value: AxisValue) -> String {
        guard let month = value.as(Int.self) else { return "" }
        return Calendar.current.veryShortStandaloneMonthSymbols[month - 1]
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
