package com.polyforms.shiori.features.subscription

import com.polyforms.shiori.graphql.QuotaQuery
import com.polyforms.shiori.graphql.SubscriptionStateQuery
import com.polyforms.shiori.graphql.SyncPlayEntitlementMutation
import com.polyforms.shiori.graphql.fragment.EntitlementFields
import com.polyforms.shiori.graphql.fragment.QuotaFields
import com.polyforms.shiori.graphql.type.Plan
import com.polyforms.shiori.shared.GraphQLClient
import com.polyforms.shiori.shared.Showcase
import com.polyforms.shiori.shared.ShowcaseData
import com.polyforms.shiori.shared.parseISO8601
import java.time.Instant

data class EntitlementState(
    val isPremium: Boolean,
    /** The account id Play Billing must carry on a purchase for the server to recognise it. */
    val appAccountToken: String?,
    val productId: String?,
    val expiresOn: Instant?,
)

data class QuotaState(
    val isPremium: Boolean,
    val used: Int,
    val limit: Int,
    val remaining: Int,
    val welcomeRemaining: Int,
    val totalRemaining: Int,
    val renewsOn: Instant?,
)

object SubscriptionApi {
    suspend fun state(): Pair<EntitlementState, QuotaState> {
        if (Showcase.isOn) return ShowcaseData.entitlement to ShowcaseData.quota
        val data = GraphQLClient.fetch(SubscriptionStateQuery())
        return data.entitlement.entitlementFields.asState to data.quota.quotaFields.asState
    }

    suspend fun quota(): QuotaState {
        if (Showcase.isOn) return ShowcaseData.quota
        return GraphQLClient.fetch(QuotaQuery()).quota.quotaFields.asState
    }

    suspend fun syncPlay(purchaseToken: String): EntitlementState =
        GraphQLClient.perform(SyncPlayEntitlementMutation(purchaseToken), changesLibrary = false)
            .syncPlayEntitlement.entitlementFields.asState
}

val EntitlementFields.asState: EntitlementState
    get() = EntitlementState(plan == Plan.PREMIUM, appAccountToken, productId, parseISO8601(expiresOn))

val QuotaFields.asState: QuotaState
    get() = QuotaState(plan == Plan.PREMIUM, used, limit, remaining, welcomeRemaining, totalRemaining, parseISO8601(renewsOn))
