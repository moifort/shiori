package com.polyforms.shiori.features.subscription

import android.app.Activity
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import com.polyforms.shiori.features.settings.ProfileSettingsScreen
import com.polyforms.shiori.features.subscription.components.pages.PremiumOffer
import com.polyforms.shiori.features.subscription.components.pages.SubscriptionWallKind
import com.polyforms.shiori.features.subscription.components.pages.SubscriptionWallPage
import com.polyforms.shiori.shared.AnalyticsEvent
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.styles.ShioriTheme
import com.polyforms.shiori.shared.platform.FullScreenCover
import com.polyforms.shiori.shared.platform.ShioriAlert
import com.polyforms.shiori.shared.shell.CoverVeil
import com.polyforms.shiori.shared.track

/**
 * The wall in front of the app while the account holds no subscription: there is no free plan.
 * Whether it offers the free month is Play's answer: the yearly plan carries a free phase only
 * while this Google account may still start it. The iOS `SubscriptionWallScreen`.
 */
@Composable
fun SubscriptionWallScreen() {
    val store = LocalSubscriptionStore.current
    val activity = LocalContext.current as? Activity
    var showsAccount by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { track(AnalyticsEvent.PaywallShown("wall")) }
    val offers = SubscriptionProducts.all.mapNotNull { id -> store.products.firstOrNull { it.productId == id }?.let(PremiumOffer::of) }
    val yearly = offers.firstOrNull { it.id == SubscriptionProducts.YEARLY }
    val monthly = offers.firstOrNull { it.id == SubscriptionProducts.MONTHLY }
    val savings = if (yearly != null && monthly != null && monthly.priceMicros > 0) {
        val twelve = monthly.priceMicros * 12.0
        ((twelve - yearly.priceMicros) / twelve).takeIf { it > 0 }
    } else {
        null
    }
    val kind = if (yearly?.trial != null) SubscriptionWallKind.TRIAL else SubscriptionWallKind.LAPSED
    ShioriTheme(dark = true) {
        Box(Modifier.fillMaxSize()) {
            CoverVeil(covering = true)
            SubscriptionWallPage(
                kind = kind,
                offers = offers,
                savings = savings,
                isLoading = store.isLoading,
                isPurchasing = store.isPurchasing,
                onBuy = { offer ->
                    val product = offer.product
                    if (activity != null && product != null) {
                        store.purchase(activity, product, withTrial = kind == SubscriptionWallKind.TRIAL && offer.id == SubscriptionProducts.YEARLY)
                    }
                },
                onRestore = { store.restore() },
                onAccount = { showsAccount = true },
            )
        }
    }
    if (showsAccount) FullScreenCover(onDismiss = { showsAccount = false }) { ProfileSettingsScreen() }
    store.errorMessage?.let { message ->
        ShioriAlert(L("Achat impossible"), message, onDismiss = { store.errorMessage = null })
    }
}
