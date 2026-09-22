import Foundation

/// The signed-in user's onboarding state, read at launch to decide routing.
/// `isAdmin` rides the same query so the admin surfaces cost no extra call.
struct MeState {
    let firstName: String?
    let onboardingCompleted: Bool
    let isAdmin: Bool
}

/// What a signed-in launch reads, in one request: where to route, and the plan
/// and allowance the subscription store starts from.
struct LaunchState {
    let onboardingCompleted: Bool
    let isAdmin: Bool
    let entitlement: EntitlementState
    let quota: QuotaState
}

enum OnboardingAPI {
    static func launch() async throws -> LaunchState {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.LaunchQuery()
        )
        return LaunchState(
            onboardingCompleted: data.me.onboardingCompleted,
            isAdmin: data.me.isAdmin,
            entitlement: data.entitlement.fragments.entitlementFields.asState,
            quota: data.quota.fragments.quotaFields.asState
        )
    }

    static func loadMe() async throws -> MeState {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.MeQuery()
        )
        return MeState(
            firstName: data.me.firstName,
            onboardingCompleted: data.me.onboardingCompleted,
            isAdmin: data.me.isAdmin
        )
    }

    /// Finishes onboarding and grants the welcome scans. Vinarium also sizes a
    /// cellar grid here; a library has no shape to declare up front, so a first
    /// name is all this asks for.
    static func completeOnboarding(firstName: String) async throws {
        let input = ShioriGraphQL.CompleteOnboardingInput(firstName: firstName)
        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.CompleteOnboardingMutation(input: input)
        )
    }
}
