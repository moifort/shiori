package com.polyforms.shiori.features.news.components.organisms

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.features.news.NewsFixtures
import com.polyforms.shiori.features.news.ReleaseCalendar
import com.polyforms.shiori.features.news.ReleaseDay
import com.polyforms.shiori.features.news.ReleaseMonthSection
import com.polyforms.shiori.features.news.UpcomingRelease
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.ShioriDivider
import com.polyforms.shiori.shared.components.styles.Symbol

/**
 * The upcoming releases a month at a time: the month, then a line per day with its date on the
 * left and the releases of the day beside it.
 */
@Composable
fun ReleaseList(sections: List<ReleaseMonthSection>, onOpen: (UpcomingRelease) -> Unit) {
    val colors = Shiori.colors
    Column {
        sections.forEach { section ->
            Text(
                section.title,
                Modifier.padding(start = 20.dp, end = 20.dp, top = 14.dp, bottom = 6.dp),
                style = Shiori.type.subheadline.copy(fontWeight = FontWeight.SemiBold),
                color = colors.label,
            )
            section.days.forEach { day ->
                ShioriDivider(Modifier.padding(start = 20.dp))
                Row(Modifier.padding(horizontal = 20.dp, vertical = 3.dp), horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    DateColumn(day)
                    Column(Modifier.weight(1f)) {
                        day.releases.forEach { release -> UpcomingReleaseRow(release, inset = 0.dp) { onOpen(release) } }
                    }
                }
            }
        }
    }
}

@Composable
private fun DateColumn(day: ReleaseDay) {
    val colors = Shiori.colors
    Column(Modifier.width(40.dp).padding(top = 10.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        val symbol = day.symbol
        if (symbol != null) {
            Icon(Symbol(symbol), L("Suivi"), Modifier.padding(top = 2.dp).size(20.dp), tint = colors.secondaryLabel)
        } else {
            day.weekday?.let { Text(it.uppercase(), style = Shiori.type.caption2.copy(fontWeight = FontWeight.Bold), color = colors.secondaryLabel) }
            Text(
                day.label,
                style = if (day.weekday == null) Shiori.type.footnote.copy(fontWeight = FontWeight.Bold) else Shiori.type.title2.copy(fontWeight = FontWeight.Bold),
                color = colors.label,
                textAlign = TextAlign.Center,
                maxLines = 2,
            )
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun ReleaseListPreview() = PreviewSurface(dark = true) {
    Column(Modifier.verticalScroll(rememberScrollState())) { ReleaseList(ReleaseCalendar(NewsFixtures.upcoming).sections) {} }
}
