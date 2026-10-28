import Foundation

/// What a signed-in launch reads, in one request: where to route, the first
/// name the profile shows, and the plan and allowance the subscription store
/// starts from.
struct LaunchState {
    let firstName: String?
    let avatar: AccountAvatar
    let onboardingCompleted: Bool
    let isAdmin: Bool
    let entitlement: EntitlementState
    let quota: QuotaState
}

enum OnboardingAPI {
    static func launch() async throws -> LaunchState {
        #if DEBUG
        if Showcase.isOn {
            return LaunchState(
                firstName: Showcase.firstName, avatar: .initials, onboardingCompleted: true, isAdmin: false,
                entitlement: Showcase.entitlement, quota: Showcase.quota
            )
        }
        #endif
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.LaunchQuery()
        )
        return LaunchState(
            firstName: data.me.firstName,
            avatar: accountAvatar(hero: data.me.avatarHero?.rawValue, url: data.me.avatarUrl),
            onboardingCompleted: data.me.onboardingCompleted,
            isAdmin: data.me.isAdmin,
            entitlement: data.entitlement.fragments.entitlementFields.asState,
            quota: data.quota.fragments.quotaFields.asState
        )
    }

    /// Finishes onboarding and grants the welcome scans. Vinarium also sizes a
    /// cellar grid here; a library has no shape to declare up front, so a first
    /// name is all this asks for.
    static func completeOnboarding(firstName: String) async throws {
        let input = ShioriGraphQL.CompleteOnboardingInput(firstName: firstName)
        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.CompleteOnboardingMutation(input: input),
            changesLibrary: false
        )
    }

    /// Puts a hero or a photo on the account, or takes the avatar off for the
    /// initials. Answers what the server now keeps: a photo comes back as the
    /// URL it is served from.
    static func changeAvatar(_ avatar: AccountAvatar) async throws -> AccountAvatar {
        var input = ShioriGraphQL.ChangeAvatarInput()
        switch avatar {
        case .initials: break
        case let .hero(hero): input.hero = .some(GraphQLEnum(rawValue: hero.graphQLName))
        case let .pickedPhoto(data): input.photoBase64 = .some(data.base64EncodedString())
        // Already the one the server keeps.
        case .photo: return avatar
        }
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.ChangeAvatarMutation(input: input),
            changesLibrary: false
        )
        return accountAvatar(hero: data.changeAvatar.avatarHero?.rawValue, url: data.changeAvatar.avatarUrl)
    }

    private static func accountAvatar(hero: String?, url: String?) -> AccountAvatar {
        if let hero, let avatarHero = AvatarHero(graphQLName: hero) { return .hero(avatarHero) }
        if let url, let photoURL = URL(string: url) { return .photo(photoURL) }
        return .initials
    }
}
