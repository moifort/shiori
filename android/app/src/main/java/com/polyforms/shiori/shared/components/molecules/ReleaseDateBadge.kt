package com.polyforms.shiori.shared.components.molecules

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.ReleaseDateText
import com.polyforms.shiori.shared.components.styles.Shiori
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

/** A release date as a calendar leaf: day over month, month over year, or the year alone. */
@Composable
fun ReleaseDateBadge(date: String, onGlass: Boolean = false) {
    val parts = date.split("-").mapNotNull { it.toIntOrNull() }
    fun month(n: Int) = if (onGlass) ReleaseDateText.clippedMonths.getOrElse(n - 1) { "" } else ReleaseDateText.shortMonth(n)
    val top = when (parts.size) {
        3 -> "${parts[2]}"
        2 -> month(parts[1])
        else -> parts.firstOrNull()?.toString() ?: ""
    }
    val bottom = when (parts.size) {
        3 -> month(parts[1])
        2 -> parts[0].toString()
        else -> null
    }
    val colors = Shiori.colors
    val shape = RoundedCornerShape(if (onGlass) 10.dp else 8.dp)
    Column(
        Modifier
            .size(48.dp)
            .semantics { contentDescription = ReleaseDateText.phrase(date) }
            .then(
                if (onGlass) Modifier.background(Color.White.copy(alpha = 0.15f), shape).border(1.dp, Color.White, shape)
                else Modifier.border(1.dp, colors.quaternaryLabel, shape),
            ),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(if (onGlass) 1.dp else 0.dp, Alignment.CenterVertically),
    ) {
        Text(
            top,
            style = if (onGlass) Shiori.type.headline.copy(fontWeight = FontWeight.Bold) else Shiori.type.subheadline.copy(fontWeight = FontWeight.SemiBold),
            color = if (onGlass) Color.White else colors.label,
            maxLines = 1,
        )
        if (bottom != null) {
            Text(
                bottom,
                style = if (onGlass) Shiori.type.caption2.copy(fontWeight = FontWeight.SemiBold) else Shiori.type.caption2,
                color = if (onGlass) Color.White.copy(alpha = 0.75f) else colors.secondaryLabel,
                maxLines = 1,
            )
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun ReleaseDateBadgePreview() = PreviewSurface {
    Row(Modifier.padding(16.dp)) { ReleaseDateBadge(java.time.LocalDate.now().plusDays(4).toString()) }
}
