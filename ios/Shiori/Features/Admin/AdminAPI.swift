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
            aiCostEur: m.aiCostEur,
            tokenCostEur: m.tokenCostEur,
            searchCostEur: m.searchCostEur,
            infraEur: m.infraEur,
            totalCostEur: m.totalCostEur,
            totalUsers: m.totalUsers,
            premiumTotal: m.premiumTotal,
            premiumMonthly: m.premiumMonthly,
            premiumYearly: m.premiumYearly,
            revenueProceedsEur: m.revenueProceedsEur,
            revenueGrossEur: m.revenueGrossEur,
            scans: m.scans,
            cacheHits: m.cacheHits,
            searches: m.searches,
            vision: step(m.vision.fragments.aiStepUsageFields),
            enrichment: step(m.enrichment.fragments.aiStepUsageFields),
            catalogue: step(m.catalogue.fragments.aiStepUsageFields),
            discovery: step(m.discovery.fragments.aiStepUsageFields),
            refreshedAt: m.refreshedAt.flatMap(GraphQLHelpers.parseISO8601)
        )
    }

    private static func step(_ usage: ShioriGraphQL.AiStepUsageFields) -> AdminMetrics.StepUsage {
        AdminMetrics.StepUsage(
            promptTokens: usage.promptTokens,
            outputTokens: usage.outputTokens,
            thinkingTokens: usage.thinkingTokens,
            searches: usage.searches
        )
    }
}
