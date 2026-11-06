package com.polyforms.shiori.features.subscription

/**
 * The two subscriptions sold, under the same identifiers in Play Console as in App Store
 * Connect. A typo makes the product fail to load, silently.
 */
object SubscriptionProducts {
    const val YEARLY = "com.polyforms.shiori.app.premium.yearly"
    const val MONTHLY = "com.polyforms.shiori.app.premium.monthly"

    /** Yearly first: it is the offer the sheet puts forward. */
    val all = listOf(YEARLY, MONTHLY)
}
