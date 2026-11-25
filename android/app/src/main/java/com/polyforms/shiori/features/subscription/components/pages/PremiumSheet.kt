package com.polyforms.shiori.features.subscription.components.pages

import androidx.activity.compose.LocalActivity
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.android.billingclient.api.ProductDetails
import com.polyforms.shiori.features.subscription.LocalSubscriptionStore
import com.polyforms.shiori.features.subscription.SubscriptionProducts
import com.polyforms.shiori.features.subscription.components.molecules.PremiumPromise
import com.polyforms.shiori.shared.AnalyticsEvent
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.Showcase
import com.polyforms.shiori.shared.ShowcaseData
import com.polyforms.shiori.shared.components.atoms.ToolbarIconButton
import com.polyforms.shiori.shared.components.styles.ButtonKind
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.ShioriButton
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable
import com.polyforms.shiori.shared.platform.SheetBar
import com.polyforms.shiori.shared.platform.ShioriAlert
import com.polyforms.shiori.shared.platform.ShioriSheet
import com.polyforms.shiori.shared.track
import kotlinx.coroutines.launch
import java.text.NumberFormat
import androidx.compose.ui.tooling.preview.Preview
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

enum class PremiumTrigger(val analyticsName: String) {
    SCAN_ALLOWANCE_SPENT("scan_allowance_spent"), DISCOVER("discover"), SHELF_IMPORT("shelf_import");

    val title: String
        get() = when (this) {
            SCAN_ALLOWANCE_SPENT -> L("Scans épuisés")
            DISCOVER -> L("Shiori Premium")
            SHELF_IMPORT -> L("Plusieurs livres d'un coup")
        }

    val message: String
        get() = when (this) {
            SCAN_ALLOWANCE_SPENT -> L("Tous vos scans ont été utilisés. Premium vous en donne 30 par mois, et tient votre bibliothèque à jour.")
            DISCOVER -> L("Photographiez une couverture : le livre rejoint votre bibliothèque avec son résumé et sa série. Premium vous donne 30 scans par mois.")
            SHELF_IMPORT -> L("Photographiez une étagère entière : chaque livre est reconnu, vous cochez ceux à ajouter. Réservé à Shiori Premium.")
        }
}

/** One plan as the sheet offers it. */
data class PremiumOffer(
    val id: String,
    val name: String,
    val displayPrice: String,
    val priceMicros: Long,
    val trial: String? = null,
    val product: ProductDetails? = null,
    /** The yearly price over twelve months, in the plan's currency. */
    val perMonth: String? = null,
) {
    companion object {
        /** The plan at its paid price, and the free period Play offers this account, if any: Play
         *  lists a free-trial offer only while the account may still start it. */
        fun of(product: ProductDetails): PremiumOffer? {
            val offers = product.subscriptionOfferDetails.orEmpty()
            val paid = offers.flatMap { it.pricingPhases.pricingPhaseList }.lastOrNull { it.priceAmountMicros > 0L } ?: return null
            val free = offers.flatMap { it.pricingPhases.pricingPhaseList }.firstOrNull { it.priceAmountMicros == 0L }
            val perMonth = if (paid.billingPeriod == "P1Y") {
                runCatching {
                    java.text.NumberFormat.getCurrencyInstance().apply { currency = java.util.Currency.getInstance(paid.priceCurrencyCode) }
                        .format(paid.priceAmountMicros / 12_000_000.0)
                }.getOrNull()
            } else {
                null
            }
            return PremiumOffer(
                id = product.productId,
                name = product.name,
                displayPrice = paid.formattedPrice,
                priceMicros = paid.priceAmountMicros,
                trial = free?.let { trialLabel(it.billingPeriod) },
                product = product,
                perMonth = perMonth,
            )
        }

        /** "1 mois offert" from an ISO period, "P1M". */
        fun trialLabel(period: String): String {
            val count = period.filter { it.isDigit() }.toIntOrNull() ?: 1
            return when (period.lastOrNull()) {
                'D' -> if (count == 1) L("1 jour offert") else L("%lld jours offerts", count)
                'W' -> if (count == 1) L("1 semaine offerte") else L("%lld semaines offertes", count)
                'M' -> if (count == 1) L("1 mois offert") else L("%lld mois offerts", count)
                'Y' -> if (count == 1) L("1 an offert") else L("%lld ans offerts", count)
                else -> L("Essai gratuit")
            }
        }
    }
}

object SubscriptionLinks {
    const val TERMS = "https://play.google.com/about/play-terms/"
    const val PRIVACY = "https://shiori.polyforms.co/privacy.html"
}

/** The offer: what Premium brings, the allowance left, the two plans, restore and the fine print. */
@Composable
fun PremiumSheet(trigger: PremiumTrigger, onDismiss: () -> Unit) {
    val store = LocalSubscriptionStore.current
    val activity = LocalActivity.current
    val uri = LocalUriHandler.current
    val scope = rememberCoroutineScope()
    LaunchedEffect(Unit) {
        track(AnalyticsEvent.PaywallShown(trigger.analyticsName))
        store.refresh()
    }
    val plans = if (Showcase.isOn) {
        ShowcaseData.offers
    } else {
        SubscriptionProducts.all.mapNotNull { id -> store.products.firstOrNull { it.productId == id }?.let(PremiumOffer::of) }
    }
    val yearly = plans.firstOrNull { it.id == SubscriptionProducts.YEARLY }
    val monthly = plans.firstOrNull { it.id == SubscriptionProducts.MONTHLY }
    val savings = if (yearly != null && monthly != null && monthly.priceMicros > 0) {
        val twelve = monthly.priceMicros * 12.0
        ((twelve - yearly.priceMicros) / twelve).takeIf { it > 0 }
    } else {
        null
    }
    val colors = Shiori.colors
    ShioriSheet(onDismiss) { dismiss ->
        SheetBar(leading = { ToolbarIconButton(L("Fermer"), "xmark") { dismiss() } })
        Column(
            Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 12.dp).navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(28.dp),
        ) {
            Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Icon(Symbol("sparkles"), null, Modifier.size(48.dp), tint = colors.accent)
                Text(trigger.title, style = Shiori.type.title2, color = colors.label, textAlign = TextAlign.Center)
                Text(trigger.message, style = Shiori.type.subheadline, color = colors.secondaryLabel, textAlign = TextAlign.Center)
            }
            // The same three lines as the wall: there is no free plan, so they are the app.
            PremiumPromise()
            when {
                store.isLoading && plans.isEmpty() -> Box(Modifier.fillMaxWidth().heightIn(min = 120.dp), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                plans.isEmpty() -> Text(
                    L("Les offres ne sont pas disponibles pour le moment."),
                    style = Shiori.type.footnote,
                    color = colors.secondaryLabel,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth(),
                )
                else -> Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    plans.forEach { plan ->
                        OfferButton(plan, if (plan.id == SubscriptionProducts.YEARLY) savings else null, store.isPurchasing) {
                            val product = plan.product ?: return@OfferButton
                            if (activity != null && store.purchase(activity, product)) dismiss()
                        }
                    }
                }
            }
            Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                ShioriButton(L("Restaurer mes achats"), kind = ButtonKind.PLAIN, enabled = !store.isPurchasing) { store.restore() }
                Text(
                    L("L’abonnement se renouvelle automatiquement sauf résiliation au moins 24 heures avant la fin de la période en cours. La gestion et la résiliation se font dans les abonnements Google Play."),
                    style = Shiori.type.caption2,
                    color = colors.secondaryLabel,
                    textAlign = TextAlign.Center,
                )
                Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    Text(L("Conditions d’utilisation"), style = Shiori.type.caption2, color = colors.accent, modifier = Modifier.plainClickable { uri.openUri(SubscriptionLinks.TERMS) })
                    Text(L("Confidentialité"), style = Shiori.type.caption2, color = colors.accent, modifier = Modifier.plainClickable { uri.openUri(SubscriptionLinks.PRIVACY) })
                }
            }
        }
    }
    store.errorMessage?.let { message ->
        ShioriAlert(L("Achat impossible"), message, onDismiss = { store.errorMessage = null })
    }
}

@Composable
private fun OfferButton(offer: PremiumOffer, savings: Double?, isPurchasing: Boolean, buy: suspend () -> Unit) {
    val colors = Shiori.colors
    val scope = rememberCoroutineScope()
    var buying by remember { mutableStateOf(false) }
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(colors.quaternaryLabel)
            .plainClickable(enabled = !isPurchasing) {
                buying = true
                scope.launch {
                    try {
                        buy()
                    } finally {
                        buying = false
                    }
                }
            }
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(offer.name, style = Shiori.type.headline, color = colors.label)
                if (savings != null) {
                    val percent = NumberFormat.getPercentInstance().apply { maximumFractionDigits = 0 }.format(savings)
                    // The accent is white in dark mode: a white label on it vanished. The wall's
                    // pill, in either appearance.
                    Text(
                        "-$percent",
                        style = Shiori.type.caption.copy(fontWeight = FontWeight.SemiBold),
                        color = colors.label,
                        modifier = Modifier.background(colors.label.copy(alpha = 0.16f), CircleShape).padding(horizontal = 8.dp, vertical = 2.dp),
                    )
                }
            }
            offer.trial?.let { Text(it, style = Shiori.type.caption, color = colors.secondaryLabel) }
        }
        Spacer(Modifier.width(8.dp))
        if (buying) CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp) else Text(offer.displayPrice, style = Shiori.type.headline, color = colors.label)
    }
}

@Preview(showBackground = true)
@Composable
private fun PremiumSheetPreview() = PreviewSurface {
    PremiumSheet(PremiumTrigger.DISCOVER, onDismiss = {})
}
