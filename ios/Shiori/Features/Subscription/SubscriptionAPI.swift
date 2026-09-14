import Apollo
import Foundation

/// What the server says the account is entitled to. `appAccountToken` is the UUID
/// a purchase must carry to be recognised — the app never derives it, it asks.
struct EntitlementState: Sendable {
    let isPremium: Bool
    let appAccountToken: UUID?
    let productId: String?
    let expiresOn: Date?
}

/// The scan allowance, as the server counts it: the month on one side, the scans
/// granted at onboarding on the other, and what the two add up to.
struct QuotaState: Sendable {
    let isPremium: Bool
    let used: Int
    let limit: Int
    /// What is left of the month alone — the granted scans are not in it.
    let remaining: Int
    /// Granted once, drawn down only after the month, never refilled.
    let welcomeRemaining: Int
    /// Everything that can still be scanned. The number a screen should show.
    let totalRemaining: Int
    let renewsOn: Date?
}

enum SubscriptionAPI {
    static func load() async throws -> EntitlementState {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.EntitlementQuery()
        )
        return state(
            plan: data.entitlement.plan,
            token: data.entitlement.appAccountToken,
            productId: data.entitlement.productId,
            expiresOn: data.entitlement.expiresOn
        )
    }

    static func quota() async throws -> QuotaState {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.QuotaQuery()
        )
        return QuotaState(
            isPremium: data.quota.plan.value == .premium,
            used: data.quota.used,
            limit: data.quota.limit,
            remaining: data.quota.remaining,
            welcomeRemaining: data.quota.welcomeRemaining,
            totalRemaining: data.quota.totalRemaining,
            renewsOn: GraphQLHelpers.parseISO8601(data.quota.renewsOn)
        )
    }

    /// Hand a transaction the App Store signed to the server, which verifies it
    /// and grants Premium. The only path to Premium there is.
    static func sync(signedTransaction: String) async throws -> EntitlementState {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.SyncEntitlementMutation(signedTransaction: signedTransaction)
        )
        return state(
            plan: data.syncEntitlement.plan,
            token: data.syncEntitlement.appAccountToken,
            productId: data.syncEntitlement.productId,
            expiresOn: data.syncEntitlement.expiresOn
        )
    }

    private static func state(
        plan: GraphQLEnum<ShioriGraphQL.Plan>,
        token: String,
        productId: String?,
        expiresOn: String?
    ) -> EntitlementState {
        EntitlementState(
            isPremium: plan.value == .premium,
            appAccountToken: UUID(uuidString: token),
            productId: productId,
            expiresOn: expiresOn.flatMap { GraphQLHelpers.parseISO8601($0) }
        )
    }
}
