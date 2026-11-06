package com.polyforms.shiori.features.subscription.components.molecules

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.DateText
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import java.time.Instant

/** The month's scans used against the allowance, the welcome credits beside it. */
@Composable
fun QuotaGauge(used: Int, limit: Int, renewsOn: Instant?, welcomeRemaining: Int = 0) {
    val colors = Shiori.colors
    val total = maxOf(0, limit - used) + welcomeRemaining
    val exhausted = total == 0
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(colors.quaternaryLabel).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(L("Scans ce mois-ci"), style = Shiori.type.subheadline.copy(fontWeight = FontWeight.Medium), color = colors.label)
            Spacer(Modifier.weight(1f))
            Text("$used / $limit", style = Shiori.type.subheadline, color = if (exhausted) colors.red else colors.secondaryLabel)
        }
        LinearProgressIndicator(
            progress = { minOf(used, limit).toFloat() / maxOf(limit, 1) },
            modifier = Modifier.fillMaxWidth(),
            color = if (exhausted) colors.red else colors.accent,
            trackColor = colors.fill,
            drawStopIndicator = {},
        )
        if (welcomeRemaining > 0) {
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) {
                Icon(Symbol("gift"), null, Modifier.size(14.dp), tint = colors.secondaryLabel)
                Text(L("%lld scans offerts en réserve", welcomeRemaining), style = Shiori.type.caption, color = colors.secondaryLabel)
            }
        }
        if (renewsOn != null) {
            Text(
                L("Renouvellement le %@", DateText.dayMonthLongYear(DateText.local(renewsOn))),
                style = Shiori.type.caption,
                color = colors.secondaryLabel,
            )
        }
    }
}
