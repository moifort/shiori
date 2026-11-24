package com.polyforms.shiori.features.authors.components.organisms

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.features.home.components.organisms.PosterRow
import com.polyforms.shiori.features.home.components.organisms.PosterRowItem
import com.polyforms.shiori.features.news.ReleaseSource
import com.polyforms.shiori.features.news.UpcomingRelease
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.book.PosterLabel
import com.polyforms.shiori.shared.components.molecules.RowHeader
import com.polyforms.shiori.shared.components.molecules.RowHeaderStyle
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.TextStyle
import java.util.Locale

/**
 * "Prochaines sorties": what the hearted authors announced, as the covers alone in a rail, the date
 * outlined in each cover's top corner where "Audio" sits elsewhere, and the author, "B. Sanderson",
 * in its foot. The page leaves it out when nothing is announced. A cover opens what the release
 * opens in Actualités.
 */
@Composable
fun FavoriteAuthorReleasesRail(releases: List<UpcomingRelease>, onOpen: (UpcomingRelease) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        RowHeader(L("Prochaines sorties"), Modifier.padding(horizontal = 20.dp), style = RowHeaderStyle.INLINE)
        PosterRow(releases.map { release -> PosterRowItem(release.cover, PosterLabel(releasePerson(release), cornerTag = releaseDay(release.date))) { onOpen(release) } }) {}
    }
}

/**
 * Whom the release is shown for, as "B. Sanderson" so it holds on one line: the narrator on the
 * Narrators shelf, the author elsewhere.
 */
fun releasePerson(release: UpcomingRelease): String {
    val name = if (release.source == ReleaseSource.NARRATOR) release.narrator ?: release.authors.firstOrNull() else release.authors.firstOrNull() ?: release.author?.name
    val words = (name ?: "").split(" ").filter { it.isNotEmpty() }
    if (words.size < 2) return name ?: ""
    return "${words.first().first()}. ${words.last()}"
}

/** "8 oct." for a day, "octobre" for a month, the year alone, or "Annoncé" with no date. */
fun releaseDay(date: String?): String {
    if (date.isNullOrEmpty()) return L("Annoncé")
    val parts = date.split("-").mapNotNull { it.toIntOrNull() }
    val year = parts.firstOrNull() ?: return date
    if (parts.size < 2) return year.toString()
    val day = runCatching { LocalDate.of(year, parts[1], parts.getOrElse(2) { 1 }) }.getOrNull() ?: return year.toString()
    val locale = Locale.getDefault()
    return if (parts.size > 2) day.format(DateTimeFormatter.ofPattern("d MMM", locale)) else day.month.getDisplayName(TextStyle.FULL_STANDALONE, locale)
}

@Preview(showBackground = true)
@Composable
private fun FavoriteAuthorReleasesRailPreview() = PreviewSurface {
    FavoriteAuthorReleasesRail(
        listOf(
            UpcomingRelease("1", ReleaseSource.AUTHOR, BookFormat.BOOK, "Lightbringer", listOf("Pierce Brown"), "2026-12-08", null, "Red Rising", 6, null, null, false),
            UpcomingRelease("2", ReleaseSource.SAGA, BookFormat.MANGA, "Berserk", listOf("Kentaro Miura"), "2027-01", null, "Berserk", 43, null, null, false),
        ),
    ) {}
}
