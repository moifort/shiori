import Foundation

/// The month the admin screen shows: what the bill says it costs day by day,
/// what the App Store paid, who is here and who came, and how much the app is
/// used.
struct AdminMetrics {
    /// The Google searches one Gemini step ran this month, as the app counted
    /// them — what says where the Gemini bill comes from.
    struct StepUsage {
        let searches: Int
    }

    /// What the bill says one day cost. Dated at midnight UTC.
    struct DailyCost: Identifiable {
        let day: Date
        let geminiEur: Double
        let infraEur: Double
        var id: Date { day }
    }

    /// How many sessions GA4 counted on one day. Dated at midnight UTC.
    struct DailySessions: Identifiable {
        let day: Date
        let sessions: Int
        var id: Date { day }
    }

    /// The month's bill so far, read from the billing export, which runs about
    /// a day behind: `billedThrough` is the last day it has reached.
    struct Costs {
        let geminiEur: Double
        let infraEur: Double
        let totalEur: Double
        /// The whole month at the daily average so far, nil before a first
        /// billed day.
        let projectedEur: Double?
        /// Last month's whole bill, nil when the export does not hold all of it.
        let previousMonthEur: Double?
        /// The projection against last month, as a ratio: 0.12 is 12 % more.
        let changeVsPreviousMonth: Double?
        let billedThrough: Date?
        let days: [DailyCost]
    }

    /// Midnight UTC on the month's first day: where the charts' axis starts.
    let month: Date
    /// Nil while the billing export has not answered this month.
    let costs: Costs?
    /// Nil while GA4 has not answered this month.
    let sessions: [DailySessions]?
    let totalUsers: Int
    let newUsers: Int
    let premiumTotal: Int
    let newPremium: Int
    /// What Apple pays out, nil while App Store Connect has not answered.
    let revenueProceedsEur: Double?
    let revenueGrossEur: Double?
    let scans: Int
    let cacheHits: Int
    let searches: Int
    let enrichment: StepUsage
    let catalogue: StepUsage
    let discovery: StepUsage
    /// The daily refresh's last run, nil before its first.
    let refreshedAt: Date?
}

extension AdminMetrics {
    /// The calendar the admin figures are dated in: the bill and the sessions
    /// count their days in UTC.
    static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// `"2026-10-04"` → midnight UTC that day.
    static func day(_ value: String) -> Date? {
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return utc.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// Midnight UTC on the first day of the month a moment falls in.
    static func monthStart(of moment: Date) -> Date {
        utc.date(from: utc.dateComponents([.year, .month], from: moment)) ?? moment
    }

    /// The last day of the month, at midnight UTC.
    var monthEnd: Date {
        let next = Self.utc.date(byAdding: .month, value: 1, to: month) ?? month
        return Self.utc.date(byAdding: .day, value: -1, to: next) ?? month
    }
}

// MARK: - Fixtures

extension AdminMetrics {
    private static let october = day("2026-10-01")!

    private static func days(_ count: Int, gemini: (Int) -> Double, infra: (Int) -> Double)
        -> [DailyCost]
    {
        (1...count).map { index in
            DailyCost(
                day: utc.date(byAdding: .day, value: index - 1, to: october)!,
                geminiEur: gemini(index),
                infraEur: infra(index)
            )
        }
    }

    private static let previewDays = days(
        17,
        gemini: { 0.6 + Double(($0 * 7) % 5) * 0.35 },
        infra: { 0.04 + Double($0 % 3) * 0.02 }
    )

    private static let previewSessions: [DailySessions] = (1...18).map { index in
        DailySessions(
            day: utc.date(byAdding: .day, value: index - 1, to: october)!,
            sessions: 8 + (index * 5) % 13
        )
    }

    private static func costs(_ days: [DailyCost], previous: Double?) -> Costs {
        let gemini = days.reduce(0) { $0 + $1.geminiEur }
        let infra = days.reduce(0) { $0 + $1.infraEur }
        let projected = (gemini + infra) / Double(days.count) * 31
        return Costs(
            geminiEur: gemini,
            infraEur: infra,
            totalEur: gemini + infra,
            projectedEur: projected,
            previousMonthEur: previous,
            changeVsPreviousMonth: previous.map { projected / $0 - 1 },
            billedThrough: days.last?.day,
            days: days
        )
    }

    /// Mid-October, last month known: every section filled.
    static let preview = AdminMetrics(
        month: october,
        costs: costs(previewDays, previous: 31.2),
        sessions: previewSessions,
        totalUsers: 128,
        newUsers: 23,
        premiumTotal: 14,
        newPremium: 4,
        revenueProceedsEur: 48.93,
        revenueGrossEur: 69.90,
        scans: 304,
        cacheHits: 5,
        searches: 910,
        enrichment: .init(searches: 348),
        catalogue: .init(searches: 329),
        discovery: .init(searches: 233),
        refreshedAt: utc.date(from: DateComponents(year: 2026, month: 10, day: 18, hour: 4))
    )

    /// The first billed month: no comparison with the month before.
    static let previewFirstMonth = AdminMetrics(
        month: october,
        costs: costs(Array(previewDays.prefix(3)), previous: nil),
        sessions: Array(previewSessions.prefix(4)),
        totalUsers: 2,
        newUsers: 2,
        premiumTotal: 1,
        newPremium: 1,
        revenueProceedsEur: 20.93,
        revenueGrossEur: 29.99,
        scans: 41,
        cacheHits: 1,
        searches: 476,
        enrichment: .init(searches: 210),
        catalogue: .init(searches: 180),
        discovery: .init(searches: 86),
        refreshedAt: utc.date(from: DateComponents(year: 2026, month: 10, day: 4, hour: 4))
    )

    /// Before the billing export, GA4 and the daily refresh have answered.
    static let previewBeforeRefresh = AdminMetrics(
        month: october,
        costs: nil,
        sessions: nil,
        totalUsers: 0,
        newUsers: 0,
        premiumTotal: 0,
        newPremium: 0,
        revenueProceedsEur: nil,
        revenueGrossEur: nil,
        scans: 0,
        cacheHits: 0,
        searches: 0,
        enrichment: .init(searches: 0),
        catalogue: .init(searches: 0),
        discovery: .init(searches: 0),
        refreshedAt: nil
    )
}
