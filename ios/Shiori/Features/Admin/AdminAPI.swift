import Apollo
import Foundation

enum AdminAPI {
    static func metrics() async throws -> AdminMetrics {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.AdminMetricsQuery()
        )
        let m = data.adminMetrics
        return AdminMetrics(
            month: AdminMetrics.monthStart(of: Date()),
            costs: m.costs.map(costs),
            sessions: m.sessions.map { entries in
                entries.compactMap { entry in
                    AdminMetrics.day(entry.day).map {
                        AdminMetrics.DailySessions(day: $0, sessions: entry.sessions)
                    }
                }
            },
            totalUsers: m.totalUsers,
            newUsers: m.newUsers,
            premiumTotal: m.premiumTotal,
            newPremium: m.newPremium,
            revenueProceedsEur: m.revenueProceedsEur,
            revenueGrossEur: m.revenueGrossEur,
            scans: m.scans,
            cacheHits: m.cacheHits,
            searches: m.searches,
            enrichment: step(m.enrichment.fragments.aiStepUsageFields),
            catalogue: step(m.catalogue.fragments.aiStepUsageFields),
            discovery: step(m.discovery.fragments.aiStepUsageFields),
            refreshedAt: m.refreshedAt.flatMap(GraphQLHelpers.parseISO8601)
        )
    }

    private static func costs(
        _ costs: ShioriGraphQL.AdminMetricsQuery.Data.AdminMetrics.Costs
    ) -> AdminMetrics.Costs {
        AdminMetrics.Costs(
            geminiEur: costs.geminiEur,
            infraEur: costs.infraEur,
            totalEur: costs.totalEur,
            projectedEur: costs.projectedEur,
            previousMonthEur: costs.previousMonthEur,
            changeVsPreviousMonth: costs.changeVsPreviousMonth,
            billedThrough: costs.billedThrough.flatMap(AdminMetrics.day),
            days: costs.days.compactMap { entry in
                AdminMetrics.day(entry.day).map {
                    AdminMetrics.DailyCost(
                        day: $0,
                        geminiEur: entry.geminiEur,
                        infraEur: entry.infraEur
                    )
                }
            }
        )
    }

    private static func step(_ usage: ShioriGraphQL.AiStepUsageFields) -> AdminMetrics.StepUsage {
        AdminMetrics.StepUsage(searches: usage.searches)
    }
}
