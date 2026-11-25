package com.polyforms.shiori.features.subscription

import androidx.compose.runtime.Composable
import com.polyforms.shiori.features.subscription.components.pages.PremiumSheet
import com.polyforms.shiori.features.subscription.components.pages.PremiumTrigger
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.platform.ShioriAlert
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * What a scan refused for want of scans brings up. There is no free plan, so a subscriber is the
 * one who meets it: the month's 30 scans spent, told when the counter starts again, never sold the
 * plan they hold. An account without Premium still gets the offer. The iOS `allowanceSpent`.
 */
@Composable
fun AllowanceSpent(trigger: PremiumTrigger, onDismiss: () -> Unit) {
    val store = LocalSubscriptionStore.current
    if (store.isPremium != true) {
        PremiumSheet(trigger, onDismiss)
        return
    }
    val renewsOn = store.quota?.renewsOn
    val message = if (renewsOn == null) {
        L("Vos 30 scans du mois sont utilisés. Le compteur repart le mois prochain.")
    } else {
        val day = DateTimeFormatter.ofPattern("d MMMM", Locale.getDefault()).format(renewsOn.atZone(ZoneId.systemDefault()))
        L("Vos 30 scans du mois sont utilisés. Le compteur repart le %@.", day)
    }
    ShioriAlert(L("Scans du mois utilisés"), message, onDismiss = onDismiss)
}
