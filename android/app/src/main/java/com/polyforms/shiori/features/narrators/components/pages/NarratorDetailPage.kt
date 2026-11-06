package com.polyforms.shiori.features.narrators.components.pages

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.authors.components.pages.PageSection
import com.polyforms.shiori.features.authors.components.pages.PersonHero
import com.polyforms.shiori.features.home.components.organisms.PosterRow
import com.polyforms.shiori.features.home.components.organisms.PosterRowItem
import com.polyforms.shiori.features.narrators.NarratorPage
import com.polyforms.shiori.features.series.components.organisms.SeriesCardRail
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.book.BookQuickAction
import com.polyforms.shiori.shared.book.PosterLabel
import com.polyforms.shiori.shared.components.molecules.FailureState
import com.polyforms.shiori.shared.components.molecules.personOrigin
import com.polyforms.shiori.shared.components.styles.Shiori
import kotlinx.coroutines.launch
import java.text.NumberFormat

sealed interface NarratorAction {
    data class OpenBook(val book: Book) : NarratorAction
    data class OpenSeries(val seriesId: String) : NarratorAction
    data class Menu(val book: Book, val action: BookQuickAction) : NarratorAction
    data object Refresh : NarratorAction
}

private const val TWO_ROWS_FROM = 6

/** A narrator: portrait, biography and figures, then the sagas and books they read. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NarratorDetailPage(page: NarratorPage?, isLoading: Boolean, errorMessage: String?, onAction: suspend (NarratorAction) -> Unit) {
    val scope = rememberCoroutineScope()
    fun send(action: NarratorAction) {
        scope.launch { onAction(action) }
    }
    when {
        isLoading && page == null -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
        page != null -> {
            var refreshing by remember { mutableStateOf(false) }
            PullToRefreshBox(refreshing, onRefresh = {
                refreshing = true
                scope.launch {
                    onAction(NarratorAction.Refresh)
                    refreshing = false
                }
            }) {
                Column(
                    Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(bottom = 32.dp),
                    verticalArrangement = Arrangement.spacedBy(30.dp),
                ) {
                    PersonHero(
                        page.name,
                        page.initials,
                        page.portraitURL,
                        page.backdropURL,
                        personOrigin(page.nationality, page.birthYear, page.deathYear)?.let { L("Narrateur · %@", it) } ?: L("Narrateur"),
                        page.biography,
                        if (page.bookCount > 0) figures(page) else null,
                    )
                    if (page.sagas.isNotEmpty()) {
                        PageSection(L("Séries")) { SeriesCardRail(page.sagas) { send(NarratorAction.OpenSeries(it.seriesId)) } }
                    }
                    if (page.books.isNotEmpty()) {
                        PageSection(L("Livres")) {
                            PosterRow(
                                page.books.map { PosterRowItem(it, PosterLabel.of(it, PosterLabel.Context.RECENT)) },
                                rows = if (page.books.size >= TWO_ROWS_FROM) 2 else 1,
                                onMenu = { book, action -> send(NarratorAction.Menu(book, action)) },
                            ) { send(NarratorAction.OpenBook(it)) }
                        }
                    }
                    if (page.bookCount == 0) {
                        Text(
                            L("Aucun de vos livres audio n'est lu par %@.", page.name),
                            style = Shiori.type.callout,
                            color = Shiori.colors.secondaryLabel,
                            textAlign = TextAlign.Center,
                            modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp),
                        )
                    }
                }
            }
        }
        else -> Box(Modifier.fillMaxSize().statusBarsPadding(), contentAlignment = Alignment.Center) {
            FailureState(L("Fiche indisponible"), errorMessage ?: L("Aucun livre audio de ce narrateur dans votre bibliothèque.")) { onAction(NarratorAction.Refresh) }
        }
    }
}

private fun figures(page: NarratorPage): List<Pair<String, String>> {
    val number = NumberFormat.getIntegerInstance()
    val held = page.books + page.sagas.flatMap { it.volumes }
    val pile = held.count { it.status == ReadingStatus.TO_READ }
    return buildList {
        add(number.format(page.readCount) to L("écoutés"))
        add(number.format(pile) to L("à écouter"))
        page.averageRating?.let { add("★ ${String.format("%.1f", it)}" to L("moyenne")) }
        add(number.format(page.seriesCount) to if (page.seriesCount > 1) L("séries") else L("série"))
    }
}
