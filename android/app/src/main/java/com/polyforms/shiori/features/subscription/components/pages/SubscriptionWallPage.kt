package com.polyforms.shiori.features.subscription.components.pages

import androidx.compose.foundation.background
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.features.subscription.SubscriptionProducts
import com.polyforms.shiori.features.subscription.components.molecules.PremiumPromise
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.styles.ActionButton
import com.polyforms.shiori.shared.components.styles.ActionLabel
import com.polyforms.shiori.shared.components.styles.ActionSize
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable
import kotlinx.coroutines.launch
import java.text.NumberFormat

/** Whether the wall offers the free month or the plans as they are. */
enum class SubscriptionWallKind { TRIAL, LAPSED }

/**
 * What stands in for the app while the account holds no subscription: there is no free plan.
 * A new reader meets it at the end of the onboarding, as the free month; a reader whose trial
 * or subscription ended meets it at launch. The library is kept; account deletion stays one tap
 * away. The iOS `SubscriptionWallPage`.
 */
@Composable
fun SubscriptionWallPage(
    kind: SubscriptionWallKind,
    offers: List<PremiumOffer>,
    savings: Double?,
    isLoading: Boolean,
    isPurchasing: Boolean,
    onBuy: suspend (PremiumOffer) -> Unit,
    onRestore: suspend () -> Unit,
    onAccount: () -> Unit,
) {
    val colors = Shiori.colors
    val scope = rememberCoroutineScope()
    var chosen by remember { mutableStateOf<String?>(null) }
    val yearly = offers.firstOrNull { it.id == SubscriptionProducts.YEARLY }
    val monthly = offers.firstOrNull { it.id == SubscriptionProducts.MONTHLY }
    val selected = offers.firstOrNull { it.id == chosen } ?: offers.firstOrNull()
    val trial = kind == SubscriptionWallKind.TRIAL
    val buyable = if (trial) yearly else selected
    val buy: @Composable () -> Unit = {
        ActionButton({ buyable?.let { scope.launch { onBuy(it) } } }, Modifier.fillMaxWidth(), size = ActionSize.LARGE, spansWidth = true, enabled = !isPurchasing && buyable != null) {
            Box(contentAlignment = Alignment.Center) {
                Row(Modifier.graphicsLayer { alpha = if (isPurchasing) 0f else 1f }) {
                    ActionLabel(if (trial) L("Commencer le mois offert") else L("S’abonner"), null, ActionSize.LARGE.side)
                }
                if (isPurchasing) CircularProgressIndicator(Modifier.size(20.dp), color = Color.Black, strokeWidth = 2.dp)
            }
        }
        if (trial) monthly?.let { offer ->
            Text(
                L("Ou %@ par mois, sans essai", offer.displayPrice),
                style = Shiori.type.subheadline,
                color = Color.White,
                modifier = Modifier.plainClickable(enabled = !isPurchasing) { scope.launch { onBuy(offer) } },
            )
        }
    }
    Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(16.dp),
            horizontalAlignment = if (trial) Alignment.Start else Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(24.dp),
        ) {
            if (trial) {
                Box(Modifier.size(88.dp).background(colors.orange, RoundedCornerShape(22.dp)), contentAlignment = Alignment.Center) {
                    Icon(Symbol("books.vertical.fill"), null, Modifier.size(44.dp), tint = Color.White)
                }
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(L("Votre mois offert"), style = Shiori.type.title.copy(fontWeight = FontWeight.Bold), color = Color.White)
                    Text(L("Shiori s’utilise avec un abonnement. Le premier mois est offert, et rien n’est prélevé si vous résiliez avant sa fin."), style = Shiori.type.subheadline, color = colors.secondaryLabel)
                }
                PremiumPromise(Modifier.clip(RoundedCornerShape(12.dp)).background(colors.secondaryGroupedBackground).padding(horizontal = 12.dp))
            } else {
                Column(Modifier.padding(top = 12.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Icon(Symbol("sparkles"), null, Modifier.size(44.dp), tint = Color.White)
                    Text(L("Votre essai est terminé"), style = Shiori.type.title2.copy(fontWeight = FontWeight.Bold), color = Color.White, textAlign = TextAlign.Center)
                    Text(L("Vos livres, vos séries et vos notes sont gardés. Abonnez-vous pour retrouver votre bibliothèque."), style = Shiori.type.subheadline, color = colors.secondaryLabel, textAlign = TextAlign.Center)
                }
                PremiumPromise()
            }
            when {
                offers.isEmpty() && isLoading -> Box(Modifier.fillMaxWidth().heightIn(min = 80.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
                offers.isEmpty() -> Text(L("Les offres ne sont pas disponibles pour le moment."), style = Shiori.type.footnote, color = colors.secondaryLabel, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
                trial -> yearly?.let { offer ->
                    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(colors.tertiaryGroupedBackground).padding(horizontal = 16.dp, vertical = 14.dp), verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                            Text(offer.trial ?: L("1 mois offert"), style = Shiori.type.headline, color = Color.White)
                            Text(L("puis %@ par an", offer.displayPrice), style = Shiori.type.caption, color = colors.secondaryLabel)
                        }
                        Pill(L("Résiliable à tout moment"))
                    }
                }
                else -> Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    offers.forEach { offer ->
                        val isSelected = offer.id == selected?.id
                        Row(
                            Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(colors.tertiaryGroupedBackground)
                                .then(if (isSelected) Modifier.border(2.dp, Color.White, RoundedCornerShape(16.dp)) else Modifier)
                                .plainClickable { chosen = offer.id }
                                .padding(horizontal = 16.dp, vertical = 14.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                                    Text(offer.name, style = Shiori.type.headline, color = Color.White)
                                    if (offer.id == SubscriptionProducts.YEARLY && savings != null) {
                                        Pill("-" + NumberFormat.getPercentInstance().apply { maximumFractionDigits = 0 }.format(savings))
                                    }
                                }
                                if (offer.id == SubscriptionProducts.YEARLY) offer.perMonth?.let {
                                    Text(L("soit %@ par mois", it), style = Shiori.type.caption, color = colors.secondaryLabel)
                                }
                            }
                            Spacer(Modifier.width(8.dp))
                            Text(offer.displayPrice, style = Shiori.type.headline, color = Color.White)
                        }
                    }
                }
            }
            if (!trial) {
                Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    buy()
                    Legal(isPurchasing, onRestore, onAccount)
                }
            }
        }
        // The free month ends the onboarding as its other pages do: the terms, then the button,
        // held at the foot of the screen.
        if (trial) {
            Column(Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, bottom = 8.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
                Legal(isPurchasing, onRestore, onAccount)
                buy()
            }
        }
    }
}

@Composable
private fun Pill(text: String) {
    Text(
        text,
        style = Shiori.type.caption.copy(fontWeight = FontWeight.SemiBold),
        color = Color.White,
        modifier = Modifier.background(Color.White.copy(alpha = 0.16f), CircleShape).padding(horizontal = 8.dp, vertical = 3.dp),
    )
}

@Composable
private fun Legal(isPurchasing: Boolean, onRestore: suspend () -> Unit, onAccount: () -> Unit) {
    val colors = Shiori.colors
    val uri = LocalUriHandler.current
    val scope = rememberCoroutineScope()
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(L("Renouvellement automatique, résiliable à tout moment dans les abonnements Google Play."), style = Shiori.type.caption, color = colors.secondaryLabel, textAlign = TextAlign.Center)
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(L("Conditions d’utilisation"), style = Shiori.type.caption, color = Color.White, modifier = Modifier.plainClickable { uri.openUri(SubscriptionLinks.TERMS) })
            Text("·", style = Shiori.type.caption, color = colors.secondaryLabel)
            Text(L("Confidentialité"), style = Shiori.type.caption, color = Color.White, modifier = Modifier.plainClickable { uri.openUri(SubscriptionLinks.PRIVACY) })
            Text("·", style = Shiori.type.caption, color = colors.secondaryLabel)
            Text(L("Restaurer mes achats"), style = Shiori.type.caption, color = Color.White, modifier = Modifier.plainClickable(enabled = !isPurchasing) { scope.launch { onRestore() } })
        }
        Text(L("Supprimer mon compte"), style = Shiori.type.caption, color = colors.secondaryLabel, modifier = Modifier.plainClickable(onClick = onAccount))
    }
}

private val previewOffers = listOf(
    PremiumOffer(SubscriptionProducts.YEARLY, "Premium annuel", "34,99 €", 34_990_000, trial = "1 mois offert", perMonth = "2,92 €"),
    PremiumOffer(SubscriptionProducts.MONTHLY, "Premium mensuel", "4,99 €", 4_990_000),
)

@Preview(showBackground = true, backgroundColor = 0xFF000000)
@Composable
private fun SubscriptionWallTrialPreview() = PreviewSurface {
    SubscriptionWallPage(SubscriptionWallKind.TRIAL, previewOffers, 0.42, isLoading = false, isPurchasing = false, onBuy = {}, onRestore = {}, onAccount = {})
}

@Preview(showBackground = true, backgroundColor = 0xFF000000)
@Composable
private fun SubscriptionWallLapsedPreview() = PreviewSurface {
    SubscriptionWallPage(SubscriptionWallKind.LAPSED, previewOffers, 0.42, isLoading = false, isPurchasing = false, onBuy = {}, onRestore = {}, onAccount = {})
}
