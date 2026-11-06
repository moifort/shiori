package com.polyforms.shiori.features.friends.components.organisms

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.friends.ReadingChallenge
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol

/** The challenge as the Partagé tab draws it: the verdict on top, then the podium as bars. */
@Composable
fun ReadingChallengeCard(challenge: ReadingChallenge, modifier: Modifier = Modifier) {
    val colors = Shiori.colors
    Column(modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        val verdict = challenge.verdict
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Icon(Symbol(verdict.symbol), null, Modifier.size(20.dp), tint = colors.orange)
            Text(verdict.text, style = Shiori.type.subheadline.copy(fontWeight = FontWeight.SemiBold), color = colors.label)
        }
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            challenge.visible.forEach { entry ->
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        medal(entry.rank),
                        style = if (entry.rank <= 3) Shiori.type.title3 else Shiori.type.subheadline,
                        color = colors.secondaryLabel,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.width(28.dp),
                    )
                    Text(
                        entry.name,
                        style = Shiori.type.subheadline.copy(fontWeight = if (entry.isMe) FontWeight.SemiBold else FontWeight.Normal),
                        color = if (entry.isMe) colors.accent else colors.label,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.width(84.dp),
                    )
                    BoxWithConstraints(Modifier.weight(1f).height(10.dp)) {
                        val width = if (challenge.best > 0) maxOf(10.dp, maxWidth * (entry.count.toFloat() / challenge.best)) else 10.dp
                        Box(
                            Modifier.width(width).height(10.dp)
                                .background(if (entry.isMe) colors.accent else colors.orange.copy(alpha = 0.55f), CircleShape),
                        )
                    }
                    Text(
                        "${entry.count}",
                        style = Shiori.type.subheadline.copy(fontWeight = FontWeight.SemiBold),
                        color = colors.label,
                        textAlign = TextAlign.End,
                        modifier = Modifier.widthIn(min = 24.dp),
                    )
                }
            }
        }
    }
}

private fun medal(rank: Int) = when (rank) {
    1 -> "🥇"
    2 -> "🥈"
    3 -> "🥉"
    else -> "$rank."
}
