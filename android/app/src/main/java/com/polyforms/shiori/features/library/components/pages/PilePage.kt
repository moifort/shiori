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
import com.polyforms.shiori.features.home.components.organisms.PosterRow
import com.polyforms.shiori.features.home.components.organisms.PosterRowItem
import com.polyforms.shiori.features.library.BookShelf
import com.polyforms.shiori.features.library.Pile
import com.polyforms.shiori.features.library.PileSection
import com.polyforms.shiori.features.library.PileSectionKind
import com.polyforms.shiori.features.series.NextVolume
import com.polyforms.shiori.features.series.components.organisms.SeriesUpNextRail
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookGenre
import com.polyforms.shiori.shared.FollowedSeries
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.book.BookQuickAction
import com.polyforms.shiori.shared.components.molecules.EmptyState
import com.polyforms.shiori.shared.components.molecules.FailureState
import com.polyforms.shiori.shared.components.molecules.FilterPill
import com.polyforms.shiori.shared.components.molecules.FilterPills
import com.polyforms.shiori.shared.components.molecules.RowHeader
import com.polyforms.shiori.shared.components.molecules.RowHeaderStyle
import com.polyforms.shiori.shared.platform.LargeTitle
import kotlinx.coroutines.launch

sealed interface PileAction {
    data class OpenBook(val book: Book) : PileAction
    data class OpenSeries(val series: FollowedSeries) : PileAction
    data class SelectGenre(val genre: BookGenre?) : PileAction
    data class Menu(val book: Book, val action: BookQuickAction) : PileAction
    data object OpenWishlist : PileAction
    data object Refresh : PileAction
}

/** The pile to read: what to finish, the sagas to follow on, the wishes, then the picks. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PilePage(
    pile: Pile,
    wished: List<PosterRowItem>,
    upNext: List<Pair<FollowedSeries, NextVolume>>,
    genres: List<BookGenre>,
    selectedGenre: BookGenre?,
    isLoading: Boolean,
    errorMessage: String?,
    onAction: suspend (PileAction) -> Unit,
) {
    val scope = rememberCoroutineScope()
    fun send(action: PileAction) {
        scope.launch { onAction(action) }
    }
    val sections = pile.sections.filter { it.kind != PileSectionKind.NEXT_VOLUME }
    var refreshing by remember { mutableStateOf(false) }

    @Composable
    fun FollowOn() {
        if (upNext.isNotEmpty()) SeriesUpNextRail(upNext) { send(PileAction.OpenSeries(it)) }
        if (wished.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                RowHeader(L("Liste d'envies"), Modifier.padding(horizontal = 20.dp), style = RowHeaderStyle.INLINE) { send(PileAction.OpenWishlist) }
                PosterRow(wished) { send(PileAction.OpenWishlist) }
            }
        }
    }

    PullToRefreshBox(refreshing, onRefresh = {
        refreshing = true
        scope.launch {
            onAction(PileAction.Refresh)
            refreshing = false
        }
    }, Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(28.dp)) {
            LargeTitle(BookShelf.TO_READ.title)
            if (genres.size > 1) {
                FilterPills(genres.map { FilterPill(it.name, it.label) }, selectedGenre?.name, { id -> send(PileAction.SelectGenre(id?.let { BookGenre.valueOf(it) })) })
            }
            if (sections.isEmpty() && upNext.isEmpty()) {
                Box(Modifier.fillMaxWidth().padding(top = 60.dp), contentAlignment = Alignment.Center) {
                    when {
                        errorMessage != null && !isLoading -> FailureState(L("Pile indisponible"), errorMessage) { onAction(PileAction.Refresh) }
                        isLoading -> CircularProgressIndicator()
                        else -> EmptyState("book.pages", L("Pile vide"), L("Les livres à lire et ceux en cours s'afficheront ici."))
                    }
                }
            } else {
                if (sections.firstOrNull()?.kind != PileSectionKind.TO_FINISH) FollowOn()
                sections.forEach { section ->
                    Rail(section, ::send)
                    if (section.kind == PileSectionKind.TO_FINISH) FollowOn()
                }
            }
        }
    }
}

@Composable
private fun Rail(section: PileSection, send: (PileAction) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        RowHeader(section.kind.title, Modifier.padding(horizontal = 20.dp), style = RowHeaderStyle.INLINE)
        PosterRow(
            section.picks.map { PosterRowItem(it.book, section.label(it)) },
            onMenu = { book, action -> send(PileAction.Menu(book, action)) },
        ) { send(PileAction.OpenBook(it)) }
    }
}
