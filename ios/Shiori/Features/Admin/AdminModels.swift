import Foundation

/// The month's figures the admin screen shows: what Gemini and GCP cost, what
/// the App Store paid, and how many readers there are.
struct AdminMetrics {
    /// The Google searches one Gemini step ran this month. Billed one by one,
    /// they are most of the Gemini bill. Reading the cover never searches.
    struct StepUsage {
        let searches: Int
    }

    let aiCostEur: Double
    let tokenCostEur: Double
    let searchCostEur: Double
    /// The project's measured GCP bill, nil while the billing export has not
    /// answered. The Apple Developer fee, shared across several apps, is left out.
    let infraEur: Double?
    let totalCostEur: Double
    let totalUsers: Int
    let premiumTotal: Int
    let premiumMonthly: Int
    let premiumYearly: Int
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
    static let preview = AdminMetrics(
        aiCostEur: 13.42,
        tokenCostEur: 0.76,
        searchCostEur: 12.66,
        infraEur: 1.18,
        totalCostEur: 14.60,
        totalUsers: 2,
        premiumTotal: 1,
        premiumMonthly: 0,
        premiumYearly: 1,
        revenueProceedsEur: 20.93,
        revenueGrossEur: 29.99,
        scans: 304,
        cacheHits: 5,
        searches: 910,
        enrichment: .init(searches: 348),
        catalogue: .init(searches: 329),
        discovery: .init(searches: 233),
        refreshedAt: Date(timeIntervalSince1970: 1_791_014_400)
    )

    static let previewBeforeRefresh = AdminMetrics(
        aiCostEur: 0,
        tokenCostEur: 0,
        searchCostEur: 0,
        infraEur: nil,
        totalCostEur: 0,
        totalUsers: 0,
        premiumTotal: 0,
        premiumMonthly: 0,
        premiumYearly: 0,
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
