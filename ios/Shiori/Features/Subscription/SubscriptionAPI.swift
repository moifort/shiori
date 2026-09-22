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
    /// The plan and the allowance, in one request: what the subscription sheet
    /// draws.
    static func state() async throws -> (entitlement: EntitlementState, quota: QuotaState) {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.SubscriptionStateQuery()
        )
        return (
            entitlement: data.entitlement.fragments.entitlementFields.asState,
            quota: data.quota.fragments.quotaFields.asState
        )
    }

    static func quota() async throws -> QuotaState {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.QuotaQuery()
        )
        return data.quota.fragments.quotaFields.asState
    }

    /// Hand a transaction the App Store signed to the server, which verifies it
    /// and grants Premium. The only path to Premium there is.
    static func sync(signedTransaction: String) async throws -> EntitlementState {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.SyncEntitlementMutation(signedTransaction: signedTransaction)
        )
        return data.syncEntitlement.fragments.entitlementFields.asState
    }
}

extension ShioriGraphQL.EntitlementFields {
    var asState: EntitlementState {
        EntitlementState(
            isPremium: plan.value == .premium,
            appAccountToken: UUID(uuidString: appAccountToken),
            productId: productId,
            expiresOn: expiresOn.flatMap { GraphQLHelpers.parseISO8601($0) }
        )
    }
}

extension ShioriGraphQL.QuotaFields {
    var asState: QuotaState {
        QuotaState(
            isPremium: plan.value == .premium,
            used: used,
            limit: limit,
            remaining: remaining,
            welcomeRemaining: welcomeRemaining,
            totalRemaining: totalRemaining,
            renewsOn: GraphQLHelpers.parseISO8601(renewsOn)
        )
    }
}
