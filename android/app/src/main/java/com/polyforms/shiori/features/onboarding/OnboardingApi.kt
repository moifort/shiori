package com.polyforms.shiori.features.onboarding

import android.util.Base64
import com.apollographql.apollo.api.Optional
import com.polyforms.shiori.features.subscription.EntitlementState
import com.polyforms.shiori.features.subscription.QuotaState
import com.polyforms.shiori.features.subscription.asState
import com.polyforms.shiori.graphql.ChangeAvatarMutation
import com.polyforms.shiori.graphql.CompleteOnboardingMutation
import com.polyforms.shiori.graphql.LaunchQuery
import com.polyforms.shiori.graphql.type.ChangeAvatarInput
import com.polyforms.shiori.graphql.type.CompleteOnboardingInput
import com.polyforms.shiori.shared.GraphQLClient
import com.polyforms.shiori.shared.Showcase
import com.polyforms.shiori.shared.ShowcaseData
import com.polyforms.shiori.shared.account.AccountAvatar
import com.polyforms.shiori.shared.account.AvatarColor
import com.polyforms.shiori.shared.account.AvatarHero
import com.polyforms.shiori.graphql.type.AvatarColor as GAvatarColor
import com.polyforms.shiori.graphql.type.AvatarHero as GAvatarHero

/** Everything a signed-in launch needs, in one request. */
data class LaunchState(
    val firstName: String?,
    val avatar: AccountAvatar,
    val onboardingCompleted: Boolean,
    val isAdmin: Boolean,
    val entitlement: EntitlementState,
    val quota: QuotaState,
)

object OnboardingApi {
    suspend fun launch(): LaunchState {
        if (Showcase.isOn) return LaunchState(ShowcaseData.firstName, AccountAvatar.Initials, true, false, ShowcaseData.entitlement, ShowcaseData.quota)
        val data = GraphQLClient.fetch(LaunchQuery())
        return LaunchState(
            firstName = data.me.firstName,
            avatar = avatar(data.me.avatarHero?.rawValue, data.me.avatarColor?.rawValue, data.me.avatarUrl),
            onboardingCompleted = data.me.onboardingCompleted,
            isAdmin = data.me.isAdmin,
            entitlement = data.entitlement.entitlementFields.asState,
            quota = data.quota.quotaFields.asState,
        )
    }

    suspend fun completeOnboarding(firstName: String) {
        GraphQLClient.perform(CompleteOnboardingMutation(CompleteOnboardingInput(firstName = firstName)), changesLibrary = false)
    }

    suspend fun changeAvatar(avatar: AccountAvatar): AccountAvatar {
        val input = when (avatar) {
            AccountAvatar.Initials -> ChangeAvatarInput()
            is AccountAvatar.Tinted -> ChangeAvatarInput(color = Optional.present(GAvatarColor.safeValueOf(avatar.color.graphQLName)))
            is AccountAvatar.Hero -> ChangeAvatarInput(hero = Optional.present(GAvatarHero.safeValueOf(avatar.hero.graphQLName)))
            is AccountAvatar.PickedPhoto -> ChangeAvatarInput(photoBase64 = Optional.present(Base64.encodeToString(avatar.data, Base64.NO_WRAP)))
            is AccountAvatar.Photo -> return avatar
        }
        val changed = GraphQLClient.perform(ChangeAvatarMutation(input), changesLibrary = false).changeAvatar
        return avatar(changed.avatarHero?.rawValue, changed.avatarColor?.rawValue, changed.avatarUrl)
    }

    private fun avatar(hero: String?, color: String?, url: String?): AccountAvatar {
        hero?.let(AvatarHero::ofGraphQL)?.let { return AccountAvatar.Hero(it) }
        color?.let { c -> AvatarColor.entries.firstOrNull { it.name == c } }?.let { return AccountAvatar.Tinted(it) }
        if (url != null) return AccountAvatar.Photo(url)
        return AccountAvatar.Initials
    }
}
