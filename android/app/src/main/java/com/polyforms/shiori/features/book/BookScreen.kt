package com.polyforms.shiori.features.book

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.authors.AuthorScreen
import com.polyforms.shiori.features.book.components.organisms.BookActionsMenu
import com.polyforms.shiori.features.book.components.organisms.BookMenuAction
import com.polyforms.shiori.features.book.components.pages.BookEditSheet
import com.polyforms.shiori.features.book.components.pages.BookField
import com.polyforms.shiori.features.book.components.pages.BookPage
import com.polyforms.shiori.features.book.components.pages.CoverPickerSheet
import com.polyforms.shiori.features.book.components.pages.FieldEditSheet
import com.polyforms.shiori.features.book.components.pages.GenreEditSheet
import com.polyforms.shiori.features.book.components.pages.RatingPromptSheet
import com.polyforms.shiori.features.book.components.pages.ReadingProgressSheet
import com.polyforms.shiori.features.book.components.pages.RecommendationSheet
import com.polyforms.shiori.features.book.components.pages.SeriesJoinSheet
import com.polyforms.shiori.features.discover.AwaitedApi
import com.polyforms.shiori.features.discover.AwaitedEditionScreen
import com.polyforms.shiori.features.narrators.NarratorScreen
import com.polyforms.shiori.features.search.RecentlyViewed
import com.polyforms.shiori.features.series.SeriesScreen
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.DataChanges
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.SeriesStripItem
import com.polyforms.shiori.shared.components.atoms.ToolbarIconButton
import com.polyforms.shiori.shared.components.molecules.EmptyState
import com.polyforms.shiori.shared.components.molecules.GeneratingPillHost
import com.polyforms.shiori.shared.components.molecules.MessageComposer
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.platform.ScreenBar
import com.polyforms.shiori.shared.platform.ShioriAlert
import com.polyforms.shiori.shared.platform.currentNavigator
import kotlinx.coroutines.launch

/** One of the reader's books, pushed from anywhere: its page, its sheets, its writes. */
@Composable
fun BookScreen(
    bookId: String,
    onChanged: (Book) -> Unit = {},
    onDeleted: (String) -> Unit = {},
    client: BookClient = BookClient.live,
) {
    val scope = rememberCoroutineScope()
    val viewModel = remember(bookId) { BookViewModel(bookId, client, scope) }
    val navigator = currentNavigator
    var sheet by remember { mutableStateOf<Sheet?>(null) }
    var composingNote by remember { mutableStateOf(false) }

    fun run(operation: suspend () -> Unit) {
        scope.launch {
            operation()
            viewModel.book?.let(onChanged)
        }
    }
    suspend fun failure(saved: Boolean): String? {
        viewModel.book?.let(onChanged)
        if (saved) return null
        val message = viewModel.errorMessage ?: L("Une erreur est survenue")
        viewModel.dismissError()
        return message
    }

    LaunchedEffect(bookId) {
        RecentlyViewed().remember(bookId)
        viewModel.load()
        viewModel.loadSagaVolumes()
        if (viewModel.describeIfAwaiting()) viewModel.book?.let(onChanged)
    }
    LaunchedEffect(bookId) { viewModel.loadOffer() }
    LaunchedEffect(bookId) { AwaitedApi.didChange.collect { viewModel.loadOffer() } }
    LaunchedEffect(bookId) { DataChanges.notices.collect { if (it == null) viewModel.refresh() } }

    Box(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground)) {
        val book = viewModel.book
        when {
            book != null -> {
                BookPage(
                    book = book,
                    isSaving = viewModel.isSaving,
                    onSetStatus = { status -> run { viewModel.setStatus(status) } },
                    onRate = { sheet = Sheet.Rating },
                    onOpenSeries = { book.series?.let { s -> navigator.push { SeriesScreen(s.id) } } },
                    onEdit = { sheet = Sheet.Edit },
                    onEditGenre = { sheet = Sheet.Genre },
                    onEditRecommendation = { sheet = Sheet.Recommendation },
                    onEditNote = { composingNote = true },
                    onEditField = { sheet = Sheet.Field(it) },
                    onOpenProgress = { sheet = Sheet.Progress },
                    seriesVolumes = viewModel.sagaVolumes.map { item ->
                        if (item is SeriesStripItem.Owned && item.book.id == book.id) SeriesStripItem.Owned(book) else item
                    },
                    onOpenVolume = { volume -> navigator.push { BookScreen(volume.id, client = client) } },
                    onOpenAuthor = { author -> navigator.push { AuthorScreen(author.key, author.name) } },
                    onOpenNarrator = { narrator -> navigator.push { NarratorScreen(narrator.key, narrator.name) } },
                    awaited = viewModel.offer.awaited,
                    onOpenAwaited = { edition -> navigator.push { AwaitedEditionScreen(edition) { scope.launch { viewModel.stopAwaiting(edition) } } } },
                    onStopAwaiting = { edition -> scope.launch { viewModel.stopAwaiting(edition) } },
                    isComposingNote = composingNote,
                    contentPadding = PaddingValues(bottom = 24.dp),
                )
                AnimatedVisibility(
                    composingNote,
                    Modifier.align(Alignment.BottomCenter),
                    enter = slideInVertically { it } + fadeIn(),
                    exit = slideOutVertically { it } + fadeOut(),
                ) {
                    Box(Modifier.background(Shiori.colors.groupedBackground.copy(alpha = 0.95f))) {
                        MessageComposer(
                            current = book.note,
                            maxLength = NOTE_MAX_LENGTH,
                            onCancel = { composingNote = false },
                            onSend = { note ->
                                scope.launch {
                                    if (viewModel.setNote(note)) composingNote = false
                                    viewModel.book?.let(onChanged)
                                }
                            },
                        )
                    }
                }
            }
            viewModel.isLoading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
            else -> Box(Modifier.fillMaxSize().statusBarsPadding(), contentAlignment = Alignment.Center) {
                EmptyState("book.closed", L("Livre introuvable"), viewModel.errorMessage ?: L("Ce livre n'est plus dans votre bibliothèque."))
            }
        }
        GeneratingPillHost(viewModel.isDescribing)
        if (viewModel.isSaving) {
            Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.1f)), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
        }
        ScreenBar {
            book?.let { current ->
                ToolbarIconButton(
                    if (current.favorite) L("Retirer des favoris") else L("Ajouter aux favoris"),
                    if (current.favorite) "heart.fill" else "heart",
                ) { run { viewModel.setFavorite(!current.favorite) } }
                BookActionsMenu(current, viewModel.offer) { action ->
                    when (action) {
                        BookMenuAction.Edit -> sheet = Sheet.Edit
                        BookMenuAction.ChooseCover -> sheet = Sheet.Cover
                        BookMenuAction.JoinSeries -> sheet = Sheet.JoinSeries
                        BookMenuAction.Recommend -> sheet = Sheet.Recommendation
                        is BookMenuAction.AwaitEdition -> viewModel.awaitEdition(action.format)
                        is BookMenuAction.StopAwaiting -> scope.launch { viewModel.stopAwaiting(action.edition) }
                        is BookMenuAction.SetStatus -> run { viewModel.setStatus(action.status) }
                        BookMenuAction.ToggleHidden -> run { viewModel.setHidden(!current.hidden) }
                        BookMenuAction.Delete -> scope.launch {
                            if (viewModel.delete()) {
                                onDeleted(bookId)
                                navigator.pop()
                            }
                        }
                    }
                }
            }
        }
    }

    val book = viewModel.book
    val dismiss = { sheet = null }
    if (book != null) {
        when (val current = sheet) {
            Sheet.Edit -> BookEditSheet(book, { runCatching { client.vocabulary() }.getOrNull() }, dismiss) { correction, rating ->
                failure(viewModel.save(correction, rating))
            }
            Sheet.Genre -> GenreEditSheet(book, { runCatching { client.subgenres() }.getOrDefault(emptyList()) }, dismiss) { correction ->
                failure(viewModel.save(correction, book.rating))
            }
            Sheet.JoinSeries -> SeriesJoinSheet(book, { runCatching { client.vocabulary() }.getOrNull() }, dismiss) { correction ->
                failure(viewModel.save(correction, book.rating))
            }
            Sheet.Recommendation -> RecommendationSheet(book.recommendation, dismiss) { recommendation ->
                failure(viewModel.setRecommendation(recommendation))
            }
            Sheet.Cover -> {
                LaunchedEffect(Unit) { viewModel.loadCoverChoices() }
                CoverPickerSheet(book, viewModel.coverChoices, viewModel.coverChoicesFailed, dismiss) { choice ->
                    failure(viewModel.chooseCover(choice))
                }
            }
            is Sheet.Field -> FieldEditSheet(book, current.field, dismiss) { correction -> failure(viewModel.save(correction, book.rating)) }
            Sheet.Progress -> ReadingProgressSheet(book.currentPage, book.pageCount, dismiss) { page, status ->
                failure(viewModel.recordPage(page, status))
            }
            Sheet.Rating -> RatingPromptSheet(book.rating, dismiss) { stars ->
                sheet = null
                run { viewModel.rate(stars) }
            }
            null -> Unit
        }
    }
    val error = viewModel.errorMessage
    if (error != null && book != null && sheet == null) ShioriAlert(L("Une erreur est survenue"), error, onDismiss = viewModel::dismissError)
    viewModel.awaitFailed?.let { ShioriAlert(L("Impossible de suivre ce livre"), it, onDismiss = { viewModel.awaitFailed = null }) }
}

private const val NOTE_MAX_LENGTH = 10_000

private sealed interface Sheet {
    data object Edit : Sheet
    data object Genre : Sheet
    data object JoinSeries : Sheet
    data object Recommendation : Sheet
    data object Cover : Sheet
    data object Progress : Sheet
    data object Rating : Sheet
    data class Field(val field: BookField) : Sheet
}
