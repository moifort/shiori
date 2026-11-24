package com.polyforms.shiori.features.news.components.organisms

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.features.home.Dashboard
import com.polyforms.shiori.features.home.components.organisms.PosterRow
import com.polyforms.shiori.features.home.components.organisms.PosterRowItem
import com.polyforms.shiori.features.home.components.organisms.SeriesShowCard
import com.polyforms.shiori.features.library.LibraryDestination
import com.polyforms.shiori.features.news.NewsCard
import com.polyforms.shiori.features.news.NewsFixtures
import com.polyforms.shiori.features.news.NewsShelfItem
import com.polyforms.shiori.features.news.ReleasedItem
import com.polyforms.shiori.features.news.components.pages.NewsAction
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.book.PosterCover
import com.polyforms.shiori.shared.book.PosterLabel
import com.polyforms.shiori.shared.components.molecules.ReleaseDateBadge
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable

/** A shelf's title over its rail, "Séries suivies ›": the chevron only where the title leads somewhere. */
@Composable
fun NewsShelfHeader(title: String, onMore: (() -> Unit)? = null) {
    val colors = Shiori.colors
    Row(
        Modifier
            .padding(horizontal = 20.dp)
            .then(if (onMore != null) Modifier.plainClickable(onClick = onMore) else Modifier)
            .semantics { heading() },
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(title, style = Shiori.type.title2, color = colors.label)
        if (onMore != null) Icon(Symbol("chevron.right"), null, Modifier.size(18.dp), tint = colors.secondaryLabel)
    }
}

/**
 * A rail of covers under its title: each cover names its friend, author or narrator in a pill on
 * its top corner and says its news in its foot.
 */
@Composable
fun NewsTileRail(title: String, items: List<NewsShelfItem>, onMore: (() -> Unit)? = null, onAction: (NewsAction) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        NewsShelfHeader(title, onMore)
        NewsTileRow(items, onAction)
    }
}

/** The covers of a rail, side by side, scrolling sideways. */
@Composable
fun NewsTileRow(items: List<NewsShelfItem>, onAction: (NewsAction) -> Unit) {
    LazyRow(contentPadding = PaddingValues(horizontal = 20.dp), horizontalArrangement = Arrangement.spacedBy(13.dp)) {
        items(items, key = { it.id }) { item -> NewsPersonTile(item) { onAction(NewsAction.Open(item.card)) } }
    }
}

/** "Séries suivies": a card per followed series, as the home's "Séries en cours", its news in the tag. */
@Composable
fun NewsSeriesRail(items: List<NewsShelfItem>, onAction: (NewsAction) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        NewsShelfHeader(L("Séries suivies")) { onAction(NewsAction.OpenLibrary(LibraryDestination.SeriesShelf())) }
        LazyRow(contentPadding = PaddingValues(horizontal = 20.dp), horizontalArrangement = Arrangement.spacedBy(13.dp)) {
            items(items, key = { it.id }) { item ->
                Box(Modifier.width(200.dp).height(128.dp)) {
                    SeriesShowCard(newsSeries(item), Modifier.width(200.dp).height(128.dp), tag = item.word, isCompact = true) {
                        onAction(NewsAction.Open(item.card))
                    }
                    item.day?.let { date -> Box(Modifier.align(Alignment.TopEnd).padding(10.dp)) { ReleaseDateBadge(date, onGlass = true) } }
                }
            }
        }
    }
}

/** The series as the home's card draws it, its volume's cover across: no count of the volumes read. */
fun newsSeries(item: NewsShelfItem): Dashboard.SeriesProgress {
    val cover = item.card.cover
    val name = when (val card = item.card) {
        is NewsCard.Released -> (card.item as? ReleasedItem.Release)?.release?.seriesName ?: cover.title
        is NewsCard.Upcoming -> card.release.seriesName ?: cover.title
        else -> cover.title
    }
    return Dashboard.SeriesProgress(id = item.id, name = name, isAudio = cover.format == BookFormat.AUDIOBOOK, readCount = 0, totalCount = 0, coverURL = cover.coverURL)
}

/**
 * One cover of a rail: the book as a poster, its news in the foot, and the person it is shown for
 * in a white pill on glass on its top corner. Nothing under the cover.
 */
@Composable
fun NewsPersonTile(item: NewsShelfItem, width: Dp = 102.dp, onOpen: () -> Unit) {
    val label = listOfNotNull(item.person, item.card.cover.title, item.caption).joinToString(", ")
    Box(Modifier.plainClickable(onClick = onOpen).semantics { contentDescription = label }) {
        PosterCover(item.card.cover, PosterLabel(item.caption, rating = item.rating), width = width)
        if (item.pillName != null) {
            Box(Modifier.padding(6.dp)) { NewsPersonPill(item, maxWidth = width - 12.dp) }
        }
    }
}

/**
 * "Liste d'envies": the editions the reader awaits, as posters — to come with their day, out
 * lately with "Sorti · 6 nov.", out already when asked for with "Disponible" in the foot.
 */
@Composable
fun NewsWishesRail(items: List<NewsShelfItem>, onAction: (NewsAction) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        NewsShelfHeader(L("Liste d'envies")) { onAction(NewsAction.OpenLibrary(LibraryDestination.Wishlist)) }
        PosterRow(items.map { item -> PosterRowItem(item.card.cover, item.caption) { onAction(NewsAction.Open(item.card)) } }) {}
    }
}

@Preview(showBackground = true)
@Composable
private fun NewsShelfRailsPreview() = PreviewSurface(dark = true) {
    val shelves = NewsFixtures.agenda().shelves
    Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(30.dp)) {
        NewsTileRail(L("Activité des amis"), shelves.activity) {}
        NewsTileRail(L("Coups de cœur des amis"), shelves.loves) {}
        NewsSeriesRail(shelves.series) {}
        NewsTileRail(L("Auteurs préférés"), shelves.authors) {}
        NewsTileRail(L("Narrateurs préférés"), shelves.narrators) {}
        NewsWishesRail(shelves.wishes) {}
    }
}
