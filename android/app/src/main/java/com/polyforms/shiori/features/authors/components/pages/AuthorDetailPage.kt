package com.polyforms.shiori.features.authors.components.pages

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
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
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.authors.AuthorPage
import com.polyforms.shiori.features.authors.AuthorWork
import com.polyforms.shiori.features.authors.components.organisms.AuthorAvatar
import com.polyforms.shiori.features.home.components.organisms.PosterRow
import com.polyforms.shiori.features.home.components.organisms.PosterRowItem
import com.polyforms.shiori.features.series.SeriesProposal
import com.polyforms.shiori.features.series.components.organisms.SeriesCardRail
import com.polyforms.shiori.features.series.nextRelease
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.ReleaseDateText
import com.polyforms.shiori.shared.book.BookQuickAction
import com.polyforms.shiori.shared.book.CoverBackdrop
import com.polyforms.shiori.shared.book.PosterLabel
import com.polyforms.shiori.shared.components.molecules.FailureState
import com.polyforms.shiori.shared.components.molecules.PersonBiography
import com.polyforms.shiori.shared.components.molecules.RowHeader
import com.polyforms.shiori.shared.components.molecules.RowHeaderStyle
import com.polyforms.shiori.shared.components.molecules.personOrigin
import com.polyforms.shiori.shared.components.styles.Shiori
import kotlinx.coroutines.launch
import java.text.NumberFormat
import androidx.compose.ui.tooling.preview.Preview
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

/** What the author page asks of its screen. */
sealed interface AuthorAction {
    data class OpenBook(val book: Book) : AuthorAction
    data class OpenSeries(val seriesId: String, val proposal: SeriesProposal? = null) : AuthorAction
    data class OpenWork(val work: AuthorWork) : AuthorAction
    data class Menu(val book: Book, val action: BookQuickAction) : AuthorAction
    data object Refresh : AuthorAction
}

private val portraitSize = 160.dp
private const val TWO_ROWS_FROM = 6

/** An author: portrait, origin, biography and figures, then their sagas, books and what to discover. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AuthorDetailPage(page: AuthorPage?, isLoading: Boolean, errorMessage: String?, onAction: suspend (AuthorAction) -> Unit) {
    val scope = rememberCoroutineScope()
    fun send(action: AuthorAction) {
        scope.launch { onAction(action) }
    }
    when {
        isLoading && page == null -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
        page != null -> {
            var refreshing by remember { mutableStateOf(false) }
            PullToRefreshBox(refreshing, onRefresh = {
                refreshing = true
                scope.launch {
                    onAction(AuthorAction.Refresh)
                    refreshing = false
                }
            }) {
                Column(
                    Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(bottom = 32.dp),
                    verticalArrangement = Arrangement.spacedBy(30.dp),
                ) {
                    Hero(page)
                    if (page.sagas.isNotEmpty()) {
                        PageSection(L("Séries")) { SeriesCardRail(page.sagas) { send(AuthorAction.OpenSeries(it.seriesId)) } }
                    }
                    if (page.books.isNotEmpty()) {
                        PageSection(L("Livres")) {
                            PosterRow(
                                page.books.map { PosterRowItem(it, PosterLabel.of(it, PosterLabel.Context.RECENT)) },
                                rows = if (page.books.size >= TWO_ROWS_FROM) 2 else 1,
                                onMenu = { book, action -> send(AuthorAction.Menu(book, action)) },
                            ) { send(AuthorAction.OpenBook(it)) }
                        }
                    }
                    val discoveries = discoveries(page, ::send)
                    if (discoveries.isNotEmpty()) {
                        PageSection(L("À découvrir")) { PosterRow(discoveries) {} }
                    }
                }
            }
        }
        else -> Box(Modifier.fillMaxSize().statusBarsPadding(), contentAlignment = Alignment.Center) {
            FailureState(L("Fiche indisponible"), errorMessage ?: L("Aucun livre de cet auteur dans votre bibliothèque.")) { onAction(AuthorAction.Refresh) }
        }
    }
}

@Composable
fun PageSection(title: String, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        RowHeader(title, Modifier.padding(horizontal = 20.dp), style = RowHeaderStyle.INLINE)
        content()
    }
}

@Composable
private fun Hero(page: AuthorPage) {
    val number = NumberFormat.getIntegerInstance()
    val held = page.books + page.sagas.flatMap { it.volumes }
    val pile = held.count { it.status == ReadingStatus.TO_READ }
    val figures = buildList {
        add(number.format(page.readCount) to L("lus"))
        add(number.format(pile) to L("à lire"))
        page.author.averageRating?.let { add("★ ${String.format("%.1f", it)}" to L("moyenne")) }
        val series = page.author.seriesCount
        add(number.format(series) to if (series > 1) L("séries") else L("série"))
    }
    PersonHero(
        page.author.name,
        page.author.initials,
        page.author.portraitURL,
        page.backdropURL,
        personOrigin(page.nationality, page.birthYear, page.deathYear),
        page.biography,
        figures,
    )
}

/** A person's head: the portrait over a cover wash, name, origin, biography, figures. */
@Composable
fun PersonHero(
    name: String,
    initials: String,
    portraitURL: String?,
    backdropURL: String?,
    origin: String?,
    biography: String?,
    figures: List<Pair<String, String>>?,
) {
    val colors = Shiori.colors
    Box(Modifier.fillMaxWidth()) {
        CoverBackdrop(backdropURL, Modifier.fillMaxWidth().height(600.dp), fadeHeight = 240.dp)
        Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
            AuthorAvatar(
                initials,
                portraitURL,
                Modifier.padding(top = 128.dp).shadow(18.dp, CircleShape, ambientColor = Color.Black.copy(alpha = 0.4f), spotColor = Color.Black.copy(alpha = 0.4f)),
                size = portraitSize,
            )
            Column(Modifier.padding(horizontal = 20.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(name, style = Shiori.type.title.copy(fontWeight = FontWeight.Bold), color = colors.label, textAlign = TextAlign.Center)
                origin?.let { Text(it, style = Shiori.type.subheadline, color = colors.secondaryLabel) }
            }
            biography?.let { PersonBiography(it, Modifier.padding(horizontal = 20.dp)) }
            if (figures != null) {
                Row(Modifier.fillMaxWidth().padding(horizontal = 20.dp).padding(top = 4.dp), verticalAlignment = Alignment.Top) {
                    figures.forEach { (value, label) ->
                        Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                            Text(value, style = Shiori.type.headline, color = colors.label)
                            Text(label.uppercase(), style = Shiori.type.caption2.copy(fontWeight = FontWeight.SemiBold), color = colors.secondaryLabel)
                        }
                    }
                }
            }
        }
    }
}

/** The announced volumes of the author's sagas, their sagas and books the reader does not hold. */
private fun discoveries(page: AuthorPage, send: (AuthorAction) -> Unit): List<PosterRowItem> {
    val author = page.author.name
    val dimming = PosterLabel.SET_ASIDE_DIMMING
    val announced = page.sagas.mapNotNull { saga ->
        val release = saga.nextRelease ?: return@mapNotNull null
        val book = Book(
            id = "announced-${saga.id}",
            title = release.title,
            authors = listOf(author),
            format = if (saga.isAudio) BookFormat.AUDIOBOOK else BookFormat.BOOK,
            coverURL = release.coverURL,
            status = ReadingStatus.TO_READ,
        )
        PosterRowItem(book, PosterLabel(ReleaseDateText.short(release.date), dimming = dimming)) { send(AuthorAction.OpenSeries(saga.seriesId)) }
    }
    val sagas = page.sagasNotHeld.map { saga ->
        val book = Book(
            id = "saga-${saga.id}",
            title = saga.name,
            authors = listOf(author),
            format = if (saga.isAudio) BookFormat.AUDIOBOOK else BookFormat.BOOK,
            coverURL = saga.coverURL,
            status = ReadingStatus.TO_READ,
        )
        PosterRowItem(book, PosterLabel(L("Série"), dimming = dimming)) { send(AuthorAction.OpenSeries(saga.id, saga.proposal)) }
    }
    val works = page.booksNotHeld.map { work ->
        val book = Book(id = "work-${work.id}", title = work.title, authors = listOf(author), coverURL = work.coverURL, status = ReadingStatus.TO_READ)
        PosterRowItem(book, PosterLabel(work.publishedIn?.toString() ?: "", dimming = dimming)) { send(AuthorAction.OpenWork(work)) }
    }
    return announced + sagas + works
}

@Preview(showBackground = true)
@Composable
private fun AuthorDetailPagePreview() = PreviewSurface {
    AuthorDetailPage(DebugFixtures.authorPage, isLoading = false, errorMessage = null) {}
}
