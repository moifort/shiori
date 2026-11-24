package com.polyforms.shiori.features.news.components.pages

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.features.news.NewsFeedLayout
import com.polyforms.shiori.features.news.NewsFixtures
import com.polyforms.shiori.features.news.ReleaseCalendar
import com.polyforms.shiori.features.news.UpcomingRelease
import com.polyforms.shiori.features.news.components.organisms.ReleaseList
import com.polyforms.shiori.features.news.pillLabel
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.molecules.FilterPill
import com.polyforms.shiori.shared.components.molecules.FilterPills
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.platform.LargeTitle

/**
 * Everything announced, pure: the format pills, then the calendar a month at a time, what is dated
 * to a year alone or not at all, and last the editions awaited that nothing announced yet. With
 * nothing announced, an icon and a sentence say what will come.
 */
@Composable
fun UpcomingReleasesPage(releases: List<UpcomingRelease>, onOpen: (UpcomingRelease) -> Unit) {
    var format by remember { mutableStateOf<BookFormat?>(null) }
    val colors = Shiori.colors
    val sections = ReleaseCalendar(releases.filter { format == null || it.format == format }).sections
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(bottom = 24.dp)) {
        LargeTitle(L("À venir"))
        Box(Modifier.padding(top = 4.dp)) {
            FilterPills(NewsFeedLayout.pillFormats.map { FilterPill(it.name, it.pillLabel) }, format?.name, { id -> format = id?.let { BookFormat.valueOf(it) } })
        }
        if (sections.isEmpty()) {
            Column(
                Modifier.fillMaxWidth().padding(horizontal = 20.dp).padding(top = 72.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Icon(Symbol("calendar"), null, Modifier.size(28.dp), tint = colors.secondaryLabel)
                Text(L("Rien d'annoncé pour l'instant"), style = Shiori.type.subheadline.copy(fontWeight = FontWeight.SemiBold), color = colors.label)
                Text(
                    L("Les prochaines sorties de vos séries, de vos auteurs et de vos livres guettés s'afficheront ici."),
                    style = Shiori.type.footnote,
                    color = colors.secondaryLabel,
                    textAlign = TextAlign.Center,
                )
            }
        } else {
            Box(Modifier.padding(top = 8.dp)) { ReleaseList(sections, onOpen) }
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun UpcomingReleasesPagePreview() = PreviewSurface(dark = true) { UpcomingReleasesPage(NewsFixtures.upcoming) {} }

@Preview(showBackground = true)
@Composable
private fun UpcomingReleasesPageEmptyPreview() = PreviewSurface(dark = true) { UpcomingReleasesPage(emptyList()) {} }
