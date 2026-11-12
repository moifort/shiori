package com.polyforms.shiori.features.friends.components.pages

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.friends.FriendBook
import com.polyforms.shiori.features.friends.FriendSaga
import com.polyforms.shiori.features.friends.components.organisms.TakeButton
import com.polyforms.shiori.features.friends.components.organisms.takenFormat
import com.polyforms.shiori.features.library.LibraryMode
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ListSection
import com.polyforms.shiori.shared.LovedRank
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.SeriesState
import com.polyforms.shiori.shared.components.atoms.LanguageTag
import com.polyforms.shiori.shared.components.atoms.OpinionMark
import com.polyforms.shiori.shared.components.atoms.ReadingStatusBadge
import com.polyforms.shiori.shared.components.atoms.SagaName
import com.polyforms.shiori.shared.components.molecules.FailureState
import com.polyforms.shiori.shared.components.molecules.LoadMoreRow
import com.polyforms.shiori.shared.components.organisms.BookCover
import com.polyforms.shiori.shared.components.organisms.BookRow
import com.polyforms.shiori.shared.components.styles.FormSection
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.ShioriDivider
import com.polyforms.shiori.shared.components.styles.plainClickable
import com.polyforms.shiori.shared.lovedRank
import kotlinx.coroutines.launch
import androidx.compose.ui.tooling.preview.Preview
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

/** Everything a friend's shelf page can ask for, its rows a book or a saga. */
sealed interface FriendShelfAction<out Row> {
    data class Open<Row>(val row: Row) : FriendShelfAction<Row>
    /** The "+" of a row: onto the reader's pile, in the format they take it in. */
    data class Take<Row>(val row: Row, val format: BookFormat) : FriendShelfAction<Row>
    data object LoadMore : FriendShelfAction<Nothing>
    data object Refresh : FriendShelfAction<Nothing>
}

val FriendSaga.lovedRank: LovedRank? get() = LovedRank.of(favorite, rating)

/**
 * A friend's whole library — or the reader's own, previewed — as the reader's Library draws
 * theirs: newest first, cut into months, or the favourites ranked. Each row opens the book on
 * the friend's read-only page and carries the "+" that puts it on the reader's pile.
 */
@Composable
fun FriendLibraryPage(
    books: List<FriendBook>,
    mode: LibraryMode,
    status: ReadingStatus?,
    isWaiting: Boolean,
    loadFailed: String?,
    hasMore: Boolean,
    loadMoreFailed: Boolean,
    adding: Set<String>,
    isPreview: Boolean,
    onAction: suspend (FriendShelfAction<FriendBook>) -> Unit,
) {
    val sections = if (mode == LibraryMode.FAVORITES) ListSection.byRank(books) { it.book.lovedRank } else ListSection.byMonth(books) { it.book.shelvedAt }
    ShelfList(
        sections,
        { it.id },
        isWaiting,
        loadFailed,
        L("Bibliothèque indisponible"),
        if (status == null && mode == LibraryMode.ALL) L("Aucun livre n'a été ajouté à cette bibliothèque.") else L("Aucun livre ne correspond."),
        hasMore,
        loadMoreFailed,
        onAction,
    ) { entry, act ->
        val book = entry.book
        Row(Modifier.padding(start = 16.dp, end = 12.dp, top = 10.dp, bottom = 10.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Box(Modifier.weight(1f).plainClickable { act(FriendShelfAction.Open(entry)) }) {
                BookRow(
                    book.title,
                    book.authorLine,
                    book,
                    book.status,
                    book.rating,
                    series = book.series,
                    statusTag = if (status == null) book.status else null,
                    genre = book.genre,
                    subgenre = book.subgenres.firstOrNull(),
                    language = book.language,
                    isFavorite = book.favorite,
                )
            }
            TakeButton(entry.inLibrary || isPreview, entry.id in adding, book.format) { act(FriendShelfAction.Take(entry, it)) }
        }
    }
}

/**
 * A friend's sagas — or the reader's own, previewed — as the reader's Series tab draws theirs:
 * the name with its marks, the author, every volume on their shelf as a cover with its status.
 */
@Composable
fun FriendSeriesListPage(
    sagas: List<FriendSaga>,
    mode: LibraryMode,
    state: SeriesState?,
    isWaiting: Boolean,
    loadFailed: String?,
    hasMore: Boolean,
    loadMoreFailed: Boolean,
    adding: Set<String>,
    isPreview: Boolean,
    onAction: suspend (FriendShelfAction<FriendSaga>) -> Unit,
) {
    val colors = Shiori.colors
    val sections = if (mode == LibraryMode.FAVORITES) ListSection.byRank(sagas) { it.lovedRank } else ListSection.byMonth(sagas) { it.shelvedAt }
    ShelfList(
        sections,
        { it.id },
        isWaiting,
        loadFailed,
        L("Séries indisponibles"),
        if (state == null && mode == LibraryMode.ALL) L("Aucune série n'a été ajoutée à cette bibliothèque.") else L("Aucune série ne correspond."),
        hasMore,
        loadMoreFailed,
        onAction,
    ) { saga, act ->
        Row(Modifier.padding(start = 16.dp, end = 12.dp, top = 10.dp, bottom = 10.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Column(Modifier.weight(1f).plainClickable { act(FriendShelfAction.Open(saga)) }, verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Box(Modifier.weight(1f)) { SagaName(saga.name, saga.isAudio, Shiori.type.body.copy(fontWeight = FontWeight.Medium)) }
                        Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                            saga.language?.takeIf { it.isForeign }?.let { LanguageTag(it) }
                            saga.state?.let { Text(it.label, style = Shiori.type.caption, color = colors.secondaryLabel) }
                            OpinionMark(saga.rating, saga.favorite)
                        }
                    }
                    saga.author?.let { Text(it, style = Shiori.type.subheadline, color = colors.secondaryLabel) }
                }
                LazyRow(contentPadding = PaddingValues(top = 5.dp, end = 5.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    items(saga.volumes, key = { it.id }) { volume ->
                        Box {
                            BookCover(volume, 44.dp, showsFormatBadge = false)
                            Box(Modifier.align(Alignment.TopEnd).offset(5.dp, (-5).dp)) { ReadingStatusBadge(volume.status) }
                        }
                    }
                }
            }
            TakeButton(
                saga.inLibrary || isPreview || saga.volumes.isEmpty(),
                saga.id in adding,
                saga.takenFormat,
                addLabel = L("Ajouter la série à mes séries"),
                ownedLabel = L("Série déjà dans votre bibliothèque"),
            ) { act(FriendShelfAction.Take(saga, it)) }
        }
    }
}

/** The list both shelves share: the sections as grouped cards, the spinner, the failure, the end. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun <Row> ShelfList(
    sections: List<ListSection<Row>>,
    idOf: (Row) -> String,
    isWaiting: Boolean,
    loadFailed: String?,
    failureTitle: String,
    emptyText: String,
    hasMore: Boolean,
    loadMoreFailed: Boolean,
    onAction: suspend (FriendShelfAction<Row>) -> Unit,
    row: @Composable (Row, (FriendShelfAction<Row>) -> Unit) -> Unit,
) {
    val scope = rememberCoroutineScope()
    val act: (FriendShelfAction<Row>) -> Unit = { scope.launch { onAction(it) } }
    var refreshing by remember { mutableStateOf(false) }
    when {
        isWaiting -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
        loadFailed != null -> Box(Modifier.fillMaxSize().statusBarsPadding(), contentAlignment = Alignment.Center) {
            FailureState(failureTitle, loadFailed) { onAction(FriendShelfAction.Refresh) }
        }
        sections.isEmpty() -> Box(Modifier.fillMaxSize().padding(24.dp), contentAlignment = Alignment.Center) {
            Text(emptyText, style = Shiori.type.body, color = Shiori.colors.secondaryLabel, textAlign = TextAlign.Center)
        }
        else -> PullToRefreshBox(refreshing, onRefresh = {
            refreshing = true
            scope.launch {
                onAction(FriendShelfAction.Refresh)
                refreshing = false
            }
        }, Modifier.fillMaxSize()) {
            LazyColumn(
                Modifier.fillMaxSize().statusBarsPadding(),
                contentPadding = PaddingValues(top = 64.dp, bottom = 120.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp),
            ) {
                items(sections, key = { it.id }) { section ->
                    FormSection(section.title) {
                        section.rows.forEachIndexed { index, item ->
                            Box(Modifier.fillMaxWidth()) { row(item, act) }
                            if (index < section.rows.lastIndex) ShioriDivider()
                        }
                    }
                }
                if (hasMore) item(key = "more") { LoadMoreRow(loadMoreFailed, L("Chargement de la suite")) { onAction(FriendShelfAction.LoadMore) } }
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun FriendShelfPagesPreview() = PreviewSurface {
    FriendLibraryPage(
        books = DebugFixtures.myShelf.pile,
        mode = com.polyforms.shiori.features.library.LibraryMode.ALL,
        status = null,
        isWaiting = false,
        loadFailed = null,
        hasMore = false,
        loadMoreFailed = false,
        adding = emptySet(),
        isPreview = false,
    ) {}
}
