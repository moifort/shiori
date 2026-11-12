package com.polyforms.shiori.features.library.components.pages

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.authors.FollowedAuthor
import com.polyforms.shiori.features.authors.components.organisms.PersonPortraitRail
import com.polyforms.shiori.features.authors.components.organisms.PortraitPerson
import com.polyforms.shiori.features.home.components.organisms.PosterRow
import com.polyforms.shiori.features.home.components.organisms.PosterRowItem
import com.polyforms.shiori.features.library.BookShelf
import com.polyforms.shiori.features.library.LibraryShelves
import com.polyforms.shiori.features.library.components.organisms.GenreTileGrid
import com.polyforms.shiori.features.library.components.organisms.LibraryLink
import com.polyforms.shiori.features.library.components.organisms.LibraryLinkRows
import com.polyforms.shiori.features.library.shelfLabel
import com.polyforms.shiori.features.narrators.NarratorRow
import com.polyforms.shiori.features.series.components.organisms.SeriesCardRail
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookGenre
import com.polyforms.shiori.shared.FollowedSeries
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.book.BookQuickAction
import com.polyforms.shiori.shared.book.PosterLabel
import com.polyforms.shiori.shared.components.molecules.EmptyState
import com.polyforms.shiori.shared.components.molecules.FailureState
import com.polyforms.shiori.shared.components.molecules.FilterPill
import com.polyforms.shiori.shared.components.molecules.FilterPills
import com.polyforms.shiori.shared.components.molecules.RowHeader
import com.polyforms.shiori.shared.components.molecules.RowHeaderStyle
import com.polyforms.shiori.shared.platform.LargeTitle
import kotlinx.coroutines.launch
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.foundation.layout.Row
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

sealed interface LibraryShelvesAction {
    data class OpenBook(val book: Book) : LibraryShelvesAction
    data class OpenShelf(val shelf: BookShelf) : LibraryShelvesAction
    data object OpenSeriesShelf : LibraryShelvesAction
    data class OpenSeries(val series: FollowedSeries) : LibraryShelvesAction
    data object OpenAuthors : LibraryShelvesAction
    data class OpenAuthor(val author: FollowedAuthor) : LibraryShelvesAction
    data object OpenNarrators : LibraryShelvesAction
    data class OpenNarrator(val narrator: NarratorRow) : LibraryShelvesAction
    data object OpenWishlist : LibraryShelvesAction
    data class OpenGenre(val genre: BookGenre) : LibraryShelvesAction
    data class SelectFormat(val format: BookFormat?) : LibraryShelvesAction
    data class SelectSubgenre(val subgenre: String?) : LibraryShelvesAction
    data class Menu(val book: Book, val action: BookQuickAction) : LibraryShelvesAction
    data object Refresh : LibraryShelvesAction
}

/** The Library's first page, or a genre's: rails of covers, sagas and people under pills. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LibraryShelvesPage(
    shelves: LibraryShelves,
    formats: List<BookFormat>,
    selectedFormat: BookFormat?,
    genre: BookGenre?,
    subgenres: List<String>,
    selectedSubgenre: String?,
    isLoading: Boolean,
    errorMessage: String?,
    onAction: suspend (LibraryShelvesAction) -> Unit,
) {
    val scope = rememberCoroutineScope()
    fun send(action: LibraryShelvesAction) {
        scope.launch { onAction(action) }
    }
    var refreshing by remember { mutableStateOf(false) }
    PullToRefreshBox(refreshing, onRefresh = {
        refreshing = true
        scope.launch {
            onAction(LibraryShelvesAction.Refresh)
            refreshing = false
        }
    }, Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(bottom = 120.dp), verticalArrangement = Arrangement.spacedBy(30.dp)) {
            Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                LargeTitle(genre?.label ?: L("Bibliothèque"))
                if (genre == null && !shelves.isEmpty) {
                    LibraryLinkRows(shelves.series.isNotEmpty(), shelves.authors.isNotEmpty(), shelves.narrators.isNotEmpty()) { link ->
                        send(
                            when (link) {
                                LibraryLink.BOOKS -> LibraryShelvesAction.OpenShelf(BookShelf.ALL)
                                LibraryLink.SERIES -> LibraryShelvesAction.OpenSeriesShelf
                                LibraryLink.AUTHORS -> LibraryShelvesAction.OpenAuthors
                                LibraryLink.NARRATORS -> LibraryShelvesAction.OpenNarrators
                                LibraryLink.WISHLIST -> LibraryShelvesAction.OpenWishlist
                            },
                        )
                    }
                }
                if (genre != null && subgenres.isNotEmpty()) {
                    FilterPills(subgenres.map { FilterPill(it, it) }, selectedSubgenre, { send(LibraryShelvesAction.SelectSubgenre(it)) })
                } else if (formats.size > 1) {
                    FilterPills(formats.map { FilterPill(it.name, it.shelfLabel) }, selectedFormat?.name, { id ->
                        send(LibraryShelvesAction.SelectFormat(id?.let { BookFormat.valueOf(it) }))
                    })
                }
            }
            when {
                shelves.isEmpty -> Box(Modifier.fillMaxWidth().padding(top = 60.dp), contentAlignment = Alignment.Center) {
                    when {
                        isLoading -> CircularProgressIndicator()
                        errorMessage != null -> FailureState(L("Bibliothèque indisponible"), errorMessage) { onAction(LibraryShelvesAction.Refresh) }
                        else -> EmptyState(
                            "book.pages",
                            if (genre == null) L("Votre bibliothèque est vide") else L("Aucun livre de ce genre"),
                            L("Scannez la couverture d'un livre pour commencer."),
                        )
                    }
                }
                genre == null -> {
                    BookRail(BookShelf.RECENT, shelves.recent, PosterLabel.Context.RECENT, ::send)
                    BookRail(BookShelf.TO_READ, shelves.toRead, PosterLabel.Context.PILE, ::send)
                    BookRail(BookShelf.LOVED, shelves.favorites, PosterLabel.Context.LOVED_BY_YEAR, ::send)
                    if (shelves.genres.isNotEmpty()) {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            RowHeader(L("Par genre"), Modifier.padding(horizontal = 20.dp), style = RowHeaderStyle.INLINE)
                            GenreTileGrid(shelves.genres) { send(LibraryShelvesAction.OpenGenre(it)) }
                        }
                    }
                }
                else -> {
                    BookRail(BookShelf.TO_READ, shelves.toRead, PosterLabel.Context.PILE, ::send)
                    BookRail(BookShelf.READ, shelves.readRecently, PosterLabel.Context.READ, ::send, title = L("Lus"))
                    if (shelves.series.isNotEmpty()) {
                        Rail(L("Séries"), { send(LibraryShelvesAction.OpenSeriesShelf) }) {
                            SeriesCardRail(shelves.series) { send(LibraryShelvesAction.OpenSeries(it)) }
                        }
                    }
                    if (shelves.authors.isNotEmpty()) {
                        Rail(L("Auteurs"), { send(LibraryShelvesAction.OpenAuthors) }) {
                            PersonPortraitRail(shelves.authors, { PortraitPerson(it.key, it.name, it.initials, it.portraitURL) }) {
                                send(LibraryShelvesAction.OpenAuthor(it))
                            }
                        }
                    }
                    if (shelves.narrators.isNotEmpty()) {
                        Rail(L("Narrateurs"), { send(LibraryShelvesAction.OpenNarrators) }) {
                            PersonPortraitRail(shelves.narrators, { PortraitPerson(it.key, it.name, it.initials, it.portraitURL) }) {
                                send(LibraryShelvesAction.OpenNarrator(it))
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun Rail(title: String, onOpen: () -> Unit, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        RowHeader(title, Modifier.padding(horizontal = 20.dp), style = RowHeaderStyle.INLINE, action = onOpen)
        content()
    }
}

@Composable
private fun BookRail(shelf: BookShelf, books: List<Book>, context: PosterLabel.Context, send: (LibraryShelvesAction) -> Unit, title: String = shelf.title) {
    if (books.isEmpty()) return
    Rail(title, { send(LibraryShelvesAction.OpenShelf(shelf)) }) {
        PosterRow(
            books.map { PosterRowItem(it, PosterLabel.of(it, context)) },
            onMenu = { book, action -> send(LibraryShelvesAction.Menu(book, action)) },
        ) { send(LibraryShelvesAction.OpenBook(it)) }
    }
}

@Preview(showBackground = true)
@Composable
private fun LibraryShelvesPagePreview() = PreviewSurface {
    LibraryShelvesPage(
        shelves = com.polyforms.shiori.features.library.LibraryShelves(
            formats = listOf(com.polyforms.shiori.shared.BookFormat.BOOK, com.polyforms.shiori.shared.BookFormat.MANGA),
            recent = DebugFixtures.reading,
            toRead = DebugFixtures.toRead,
            series = DebugFixtures.followedSeries,
            authors = listOf(DebugFixtures.author),
        ),
        formats = listOf(com.polyforms.shiori.shared.BookFormat.BOOK, com.polyforms.shiori.shared.BookFormat.MANGA),
        selectedFormat = null,
        genre = null,
        subgenres = emptyList(),
        selectedSubgenre = null,
        isLoading = false,
        errorMessage = null,
    ) {}
}
