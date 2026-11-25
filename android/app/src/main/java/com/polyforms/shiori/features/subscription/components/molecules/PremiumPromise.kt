package com.polyforms.shiori.features.subscription.components.molecules

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.ShioriDivider
import com.polyforms.shiori.shared.components.styles.Symbol

/**
 * What Premium gives, in the same three lines wherever it is offered: the wall that stands in
 * for the app without a subscription, and the Premium sheet. There is no free plan, so these
 * are what the app is. The iOS `PremiumPromise`.
 */
@Composable
fun PremiumPromise(modifier: Modifier = Modifier) {
    Column(modifier.fillMaxWidth()) {
        PromiseRow("arrow.triangle.2.circlepath", L("Kindle et Audible à jour"), L("Vos achats et vos lectures arrivent chaque nuit, sans rien faire."))
        ShioriDivider(Modifier.padding(start = 44.dp))
        PromiseRow("bell", L("Alertes de sortie"), L("Le prochain tome de vos séries, dès que sa date est connue."))
        ShioriDivider(Modifier.padding(start = 44.dp))
        PromiseRow("camera.viewfinder", L("Une couverture ou une étagère en photo"), L("Chaque livre reconnu, avec son résumé et sa série. 30 scans par mois."))
    }
}

@Composable
private fun PromiseRow(symbol: String, title: String, detail: String) {
    val colors = Shiori.colors
    Row(Modifier.fillMaxWidth().padding(vertical = 10.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Icon(Symbol(symbol), null, Modifier.width(32.dp).size(24.dp), tint = colors.label)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, style = Shiori.type.body, color = colors.label)
            Text(detail, style = Shiori.type.caption, color = colors.secondaryLabel)
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun PremiumPromisePreview() = PreviewSurface { PremiumPromise(Modifier.padding(16.dp)) }
