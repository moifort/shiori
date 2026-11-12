package com.polyforms.shiori.features.library.components.pages

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyGridScope
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.layout
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.library.BookShelf
import com.polyforms.shiori.features.library.shelfLabel
import com.polyforms.shiori.features.series.components.organisms.SeriesCardRail
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookGenre
import com.polyforms.shiori.shared.FollowedSeries
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ListSection
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.book.BookContextMenuBox
import com.polyforms.shiori.shared.book.BookQuickAction
import com.polyforms.shiori.shared.book.PosterCover
import com.polyforms.shiori.shared.book.PosterLabel
import com.polyforms.shiori.shared.components.atoms.RatingStars
import com.polyforms.shiori.shared.components.molecules.EmptyState
import com.polyforms.shiori.shared.components.molecules.FailureState
import com.polyforms.shiori.shared.components.molecules.FilterPill
import com.polyforms.shiori.shared.components.molecules.FilterPills
import com.polyforms.shiori.shared.components.molecules.LoadMoreRow
import com.polyforms.shiori.shared.components.molecules.RowHeader
import com.polyforms.shiori.shared.components.molecules.RowHeaderStyle
import com.polyforms.shiori.shared.components.organisms.BookCover
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.platform.LargeTitle
import kotlinx.coroutines.launch
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.foundation.layout.Row
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

private val INSET = 20.dp

sealed interface BookShelfAction {
    data class OpenBook(val book: Book) : BookShelfAction
    data class OpenSeries(val series: FollowedSeries) : BookShelfAction
    data class SelectStatus(val status: ReadingStatus?) : BookShelfAction
    data class SelectGenre(val genre: BookGenre?) : BookShelfAction
    data class SelectFormat(val format: BookFormat?) : BookShelfAction
    data class Menu(val book: Book, val action: BookQuickAction) : BookShelfAction
    data class Reached(val id: String) : BookShelfAction
    data object LoadMore : BookShelfAction
    data object Refresh : BookShelfAction
    data object Share : BookShelfAction
}

val ReadingStatus.recentPillLabel: String
    get() = when (this) {
        ReadingStatus.TO_READ -> L("Ajoutés")
        ReadingStatus.READING -> L("En cours")
        ReadingStatus.READ -> L("Terminés")
        ReadingStatus.DROPPED -> L("Abandonnés")
    }

/** A grid page under a large title, pulled to refresh. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ShelfGrid(columns: Int, spacing: Dp, onRefresh: suspend () -> Unit, inset: Dp = 0.dp, content: LazyGridScope.() -> Unit) {
    val scope = rememberCoroutineScope()
    var refreshing by remember { mutableStateOf(false) }
    PullToRefreshBox(refreshing, onRefresh = {
        refreshing = true
        scope.launch {
            onRefresh()
            refreshing = false
        }
    }, Modifier.fillMaxSize()) {
        LazyVerticalGrid(
            GridCells.Fixed(columns),
            Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = inset, end = inset, bottom = 32.dp),
            horizontalArrangement = Arrangement.spacedBy(spacing),
            verticalArrangement = Arrangement.spacedBy(spacing),
            content = content,
        )
    }
}

/** A row across the whole grid, drawn edge to edge past the grid's inset. */
fun LazyGridScope.fullWidth(key: Any, inset: Dp = 0.dp, content: @Composable () -> Unit) = item(key = key, span = { GridItemSpan(maxLineSpan) }) {
    Box(
        Modifier.layout { measurable, constraints ->
            val extra = (inset * 2).roundToPx()
            val width = constraints.maxWidth + extra
            val placeable = measurable.measure(constraints.copy(minWidth = width, maxWidth = width))
            layout(constraints.maxWidth, placeable.height) { placeable.place(-extra / 2, 0) }
        },
    ) { content() }
}

/** One Library shelf: three posters to a row, under its period or year. */
@Composable
fun BookShelfPage(
    shelf: BookShelf,
    sections: List<ListSection<Book>>,
    lovedSeries: List<FollowedSeries>,
    statuses: List<ReadingStatus>,
    selectedStatus: ReadingStatus?,
    genres: List<BookGenre>,
    selectedGenre: BookGenre?,
    formats: List<BookFormat>,
    selectedFormat: BookFormat?,
    isLoading: Boolean,
    errorMessage: String?,
    hasMore: Boolean,
    loadMoreFailed: Boolean,
    onAction: suspend (BookShelfAction) -> Unit,
) {
    val scope = rememberCoroutineScope()
    fun send(action: BookShelfAction) {
        scope.launch { onAction(action) }
    }
    ShelfGrid(3, 13.dp, { onAction(BookShelfAction.Refresh) }, inset = INSET) {
        fullWidth(inset = INSET, key = "title") { LargeTitle(shelf.title) }
        fullWidth(inset = INSET, key = "pills") {
            Box(Modifier.padding(bottom = 4.dp)) {
                when {
                    statuses.isNotEmpty() -> FilterPills(statuses.map { FilterPill(it.name, it.recentPillLabel) }, selectedStatus?.name, { id ->
                        send(BookShelfAction.SelectStatus(id?.let { ReadingStatus.valueOf(it) }))
                    })
                    genres.isNotEmpty() -> FilterPills(genres.map { FilterPill(it.name, it.label) }, selectedGenre?.name, { id ->
                        send(BookShelfAction.SelectGenre(id?.let { BookGenre.valueOf(it) }))
                    })
                    formats.isNotEmpty() -> FilterPills(formats.map { FilterPill(it.name, it.shelfLabel) }, selectedFormat?.name, { id ->
                        send(BookShelfAction.SelectFormat(id?.let { BookFormat.valueOf(it) }))
                    })
                }
            }
        }
        if (shelf == BookShelf.DROPPED) {
            fullWidth(inset = INSET, key = "explanation") {
                Text(
                    L("Les livres arrêtés en cours de route. Ils ne comptent pas comme lus et n'apparaissent nulle part ailleurs dans la bibliothèque."),
                    style = Shiori.type.subheadline,
                    color = Shiori.colors.secondaryLabel,
                    modifier = Modifier.padding(start = 20.dp, end = 20.dp, top = 4.dp, bottom = 8.dp),
                )
            }
        }
        if (lovedSeries.isNotEmpty()) {
            fullWidth(inset = INSET, key = "loved-series") {
                Column(Modifier.padding(top = 22.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    RowHeader(L("Séries"), Modifier.padding(horizontal = 20.dp), style = RowHeaderStyle.INLINE)
                    SeriesCardRail(lovedSeries) { send(BookShelfAction.OpenSeries(it)) }
                }
            }
        }
        if (sections.isEmpty() && lovedSeries.isEmpty()) {
            fullWidth(inset = INSET, key = "empty") {
                Box(Modifier.fillMaxWidth().padding(top = 60.dp), contentAlignment = Alignment.Center) {
                    when {
                        errorMessage != null && !isLoading -> FailureState(L("Rayon indisponible"), errorMessage) { onAction(BookShelfAction.Refresh) }
                        isLoading -> CircularProgressIndicator()
                        else -> EmptyState("book.pages", L("Rien ici pour l'instant"), L("Les livres de ce rayon s'afficheront ici."))
                    }
                }
            }
        }
        sections.forEach { section ->
            fullWidth(inset = INSET, key = "header-${section.id}") {
                if (section.title.isNotEmpty()) {
                    Text(
                        section.title,
                        style = Shiori.type.title2.copy(fontWeight = FontWeight.Bold),
                        color = Shiori.colors.label,
                        modifier = Modifier.padding(start = 20.dp, end = 20.dp, top = 22.dp, bottom = 12.dp),
                    )
                } else {
                    Box(Modifier.padding(top = 14.dp))
                }
            }
            items(section.rows.size, key = { "${section.id}-${section.rows[it].id}" }) { index ->
                val book = section.rows[index]
                LaunchedEffect(book.id) { onAction(BookShelfAction.Reached(book.id)) }
                ShelfPoster(book, PosterLabel.of(book, shelf.context), { send(BookShelfAction.OpenBook(book)) }) { send(BookShelfAction.Menu(book, it)) }
            }
        }
        if (hasMore) {
            fullWidth(inset = INSET, key = "more") {
                Box(Modifier.padding(top = 20.dp)) { LoadMoreRow(loadMoreFailed, L("Chargement de la suite")) { onAction(BookShelfAction.LoadMore) } }
            }
        }
    }
}

/** A poster filling its grid cell. */
@Composable
fun ShelfPoster(book: Book, label: PosterLabel, onOpen: () -> Unit, onMenu: (BookQuickAction) -> Unit) {
    var width by remember { mutableStateOf(0.dp) }
    val density = LocalDensity.current
    BookContextMenuBox(book, onOpen, onMenu, Modifier.fillMaxWidth().aspectRatio(2f / 3f).onSizeChanged { width = with(density) { it.width.toDp() } }) {
        if (width > 0.dp) PosterCover(book, label, width = width)
    }
}

/** Every book, five covers to a row, month by month, filtered by status from the bar. */
@Composable
fun BookMosaicPage(
    sections: List<ListSection<Book>>,
    formats: List<BookFormat>,
    selectedFormat: BookFormat?,
    selectedStatus: ReadingStatus?,
    isLoading: Boolean,
    errorMessage: String?,
    hasMore: Boolean,
    loadMoreFailed: Boolean,
    onAction: suspend (BookShelfAction) -> Unit,
) {
    val scope = rememberCoroutineScope()
    fun send(action: BookShelfAction) {
        scope.launch { onAction(action) }
    }
    val isShowingDropped = selectedStatus == ReadingStatus.DROPPED
    ShelfGrid(5, 2.dp, { onAction(BookShelfAction.Refresh) }) {
        fullWidth("title") { LargeTitle(BookShelf.ALL.title) }
        if (formats.size > 1) {
            fullWidth("pills") {
                Box(Modifier.padding(bottom = 8.dp)) {
                    FilterPills(formats.map { FilterPill(it.name, it.shelfLabel) }, selectedFormat?.name, { id ->
                        send(BookShelfAction.SelectFormat(id?.let { BookFormat.valueOf(it) }))
                    })
                }
            }
        }
        if (sections.isEmpty()) {
            fullWidth("empty") {
                Box(Modifier.fillMaxWidth().padding(top = 60.dp), contentAlignment = Alignment.Center) {
                    when {
                        isLoading -> CircularProgressIndicator()
                        errorMessage != null -> FailureState(L("Bibliothèque indisponible"), errorMessage) { onAction(BookShelfAction.Refresh) }
                        selectedStatus != null -> EmptyState(selectedStatus.symbol, L("Aucun livre"), L("Aucun livre de la bibliothèque n'a ce statut."))
                    }
                }
            }
        }
        sections.forEach { section ->
            fullWidth("header-${section.id}") {
                Text(
                    section.title,
                    style = Shiori.type.subheadline.copy(fontWeight = FontWeight.SemiBold),
                    color = Shiori.colors.label,
                    modifier = Modifier.padding(start = 20.dp, end = 20.dp, top = 14.dp, bottom = 8.dp),
                )
            }
            items(section.rows, key = { "${section.id}-${it.id}" }) { book ->
                LaunchedEffect(book.id) { onAction(BookShelfAction.Reached(book.id)) }
                MosaicCover(book, isShowingDropped, { send(BookShelfAction.OpenBook(book)) }) { send(BookShelfAction.Menu(book, it)) }
            }
        }
        if (hasMore) {
            fullWidth("more") {
                Box(Modifier.padding(top = 20.dp)) { LoadMoreRow(loadMoreFailed, L("Chargement de la suite")) { onAction(BookShelfAction.LoadMore) } }
            }
        }
    }
}

@Composable
private fun MosaicCover(book: Book, isDimmed: Boolean, onOpen: () -> Unit, onMenu: (BookQuickAction) -> Unit) {
    var width by remember { mutableStateOf(0.dp) }
    val density = LocalDensity.current
    BookContextMenuBox(
        book,
        onOpen,
        onMenu,
        Modifier.fillMaxWidth().aspectRatio(2f / 3f).clipToBounds().onSizeChanged { width = with(density) { it.width.toDp() } },
    ) {
        Box(Modifier.fillMaxSize()) {
            if (width > 0.dp) BookCover(book, width, showsFormatBadge = false, cornerRadius = 0.dp)
            if (isDimmed) Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = PosterLabel.SET_ASIDE_DIMMING.toFloat())))
            val rating = book.shownRating
            if (book.favorite || rating != null) {
                Box(
                    Modifier.align(Alignment.BottomCenter).fillMaxWidth()
                        .background(Brush.verticalGradient(listOf(Color.Transparent, Color.Black.copy(alpha = 0.55f))))
                        .padding(top = 10.dp, bottom = 4.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    if (book.favorite) {
                        Icon(Symbol("heart.fill"), L("Coup de cœur"), Modifier.size(10.dp), tint = Color.White)
                    } else if (rating != null) {
                        RatingStars(rating, size = 8.dp, monochrome = true, tint = Color.White)
                    }
                }
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun BookShelfPagePreview() = PreviewSurface {
    BookShelfPage(
        shelf = com.polyforms.shiori.features.library.BookShelf.TO_READ,
        sections = listOf(com.polyforms.shiori.shared.ListSection("now", "Ce mois-ci", DebugFixtures.toRead)),
        lovedSeries = emptyList(),
        statuses = emptyList(),
        selectedStatus = null,
        genres = listOf(com.polyforms.shiori.shared.BookGenre.SCIENCE_FICTION, com.polyforms.shiori.shared.BookGenre.FANTASY),
        selectedGenre = null,
        formats = listOf(com.polyforms.shiori.shared.BookFormat.BOOK, com.polyforms.shiori.shared.BookFormat.MANGA),
        selectedFormat = null,
        isLoading = false,
        errorMessage = null,
        hasMore = false,
        loadMoreFailed = false,
    ) {}
}
