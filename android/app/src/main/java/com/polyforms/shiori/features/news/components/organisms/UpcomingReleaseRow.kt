package com.polyforms.shiori.features.news.components.organisms

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.features.news.NewsFixtures
import com.polyforms.shiori.features.news.ReleaseSource
import com.polyforms.shiori.features.news.UpcomingRelease
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.organisms.BookCover
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable

/**
 * One announced book in the calendar: its cover, its title and why the reader is told of it. An
 * announcement with no title is a "?".
 *
 * @param showsBar a bar down the left, as the day's list draws it.
 * @param month closes the subtitle: the month a release past the six months is announced for.
 */
@Composable
fun UpcomingReleaseRow(release: UpcomingRelease, showsBar: Boolean = false, month: String? = null, inset: Dp = 20.dp, onOpen: (() -> Unit)? = null) {
    val colors = Shiori.colors
    val title = release.title ?: if (release.format == BookFormat.BOOK) L("Nouveau roman") else L("Nouveau livre")
    val base = if (release.title != null) release.reason else "${release.authors.firstOrNull() ?: ""} · ${L("sans titre")}"
    val subtitle = listOfNotNull(base, month).filter { it.isNotEmpty() }.joinToString(" · ")
    Row(
        Modifier
            .fillMaxWidth()
            .height(IntrinsicSize.Min)
            .then(if (onOpen != null) Modifier.plainClickable(onClick = onOpen) else Modifier)
            .padding(horizontal = inset, vertical = 7.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (showsBar) Box(Modifier.width(3.dp).fillMaxHeight().background(Color.White.copy(alpha = 0.8f), RoundedCornerShape(50)))
        if (release.title == null) {
            Box(
                Modifier.size(30.dp, 45.dp).background(Brush.linearGradient(listOf(Color(0xFF4A4A4A), Color(0xFF2B2B2B))), RoundedCornerShape(3.dp)),
                contentAlignment = Alignment.Center,
            ) { Text("?", style = Shiori.type.caption.copy(fontWeight = FontWeight.SemiBold), color = Color.White) }
        } else {
            BookCover(release.cover, 30.dp, showsFormatBadge = false)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(title, Modifier.weight(1f, fill = false), style = Shiori.type.subheadline.copy(fontWeight = FontWeight.SemiBold), color = colors.label, maxLines = 2)
                if (release.source == ReleaseSource.AWAITED) Icon(Symbol("binoculars"), L("Suivi"), Modifier.size(12.dp), tint = colors.label)
            }
            Text(subtitle, style = Shiori.type.caption, color = colors.secondaryLabel, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun UpcomingReleaseRowPreview() = PreviewSurface(dark = true) {
    Column { NewsFixtures.upcoming.forEach { UpcomingReleaseRow(it, showsBar = true) } }
}
