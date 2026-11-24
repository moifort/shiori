package com.polyforms.shiori.features.discover

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.polyforms.shiori.features.book.BookScreen
import com.polyforms.shiori.features.discover.components.pages.AwaitedEditionAction
import com.polyforms.shiori.features.discover.components.pages.AwaitedEditionPage
import com.polyforms.shiori.features.discover.components.pages.UnownedBookAddition
import com.polyforms.shiori.features.series.SeriesScreen
import com.polyforms.shiori.features.wishlist.Wish
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.SeriesMembership
import com.polyforms.shiori.shared.SeriesStripItem
import com.polyforms.shiori.shared.components.molecules.TakenState
import com.polyforms.shiori.shared.isCancellation
import com.polyforms.shiori.shared.platform.ShioriAlert
import com.polyforms.shiori.shared.platform.currentNavigator
import com.polyforms.shiori.shared.reportError

/** An awaited edition's page: its description, asked for when it opens, and the saga of the reader's copy. */
class AwaitedEditionViewModel(val edition: AwaitedEdition, private val client: DiscoverClient) {
    private val describer = ReleaseDescriber(edition.release) { client.describe(ReleaseItem.AwaitedEdition(edition.id)) }

    /** The saga of the reader's copy, and its volumes held or lacking, its copy among them. */
    var sagaVolumes by mutableStateOf<List<SeriesStripItem>>(emptyList())
        private set

    /** The saga and the place in it of the reader's copy: the edition's own, over its title. */
    private var series by mutableStateOf<SeriesMembership?>(null)

    /** The reader's copy, read for its saga's row. */
    private var copy: Book? = null

    /** The saga of the reader's copy, as the page of a volume of it they lack reads it. */
    val lackingSaga: SagaDiscovery?
        get() {
            val copy = copy ?: return null
            val series = series ?: return null
            return SagaDiscovery.holding(copy, series, sagaVolumes.count { it is SeriesStripItem.Owned })
        }

    /** The edition as its list drew it, then as the server described it, in the saga of the reader's copy. */
    val shown: Book
        get() {
            val book = describer.release.book("awaited-${edition.id}")
            return if (book.series == null) book.copy(series = series) else book
        }
    val isDescribing: Boolean get() = describer.isDescribing
    val releaseKey: String get() = describer.release.key

    fun drawCover(url: String) = describer.drawCover(url)

    var added by mutableStateOf(false)
        private set
    var taken by mutableStateOf<TakenState?>(null)
        private set
    var isWished by mutableStateOf(false)
        private set
    var refusals by mutableStateOf(0)
        private set
    private var bookAdded: String? = null
    private var wishId: String? = null

    /** Why adding it or giving it up failed, for the alert; null once read. */
    var actionError by mutableStateOf<String?>(null)

    suspend fun describe() = describer.describe()

    /** The reader's copy, then its saga's row off the catalogue already built. Nothing when either fails. */
    suspend fun loadSaga() {
        val bookId = edition.bookId ?: return
        val book = runCatching { client.book(bookId) }.getOrNull() ?: return
        val membership = book.series ?: return
        val volumes = runCatching { client.sagaVolumes(membership.id, book.language) }.getOrNull() ?: return
        series = membership
        copy = book
        sagaVolumes = volumes
    }

    /** No longer awaited, given up from the page itself. Says whether it went; a failure is said in the alert. */
    suspend fun stopAwaiting(): Boolean = try {
        client.stopAwaiting(edition.id)
        true
    } catch (error: Throwable) {
        if (isCancellation(error)) throw error
        actionError = reportError(error)
        false
    }

    /** Onto the pile as shown, or read already. */
    suspend fun add(addition: UnownedBookAddition = UnownedBookAddition.PILE) {
        if (addition == UnownedBookAddition.WISHLIST) return toggleWish()
        try {
            var draft = edition.draft(shown)
            if (addition == UnownedBookAddition.READ) draft = draft.copy(status = ReadingStatus.READ)
            bookAdded = client.addSuggestion(draft)
            val isAudio = edition.format == ReleaseFormat.AUDIOBOOK
            taken = if (addition == UnownedBookAddition.READ) TakenState.Read(isAudio) else TakenState.ToRead(isAudio)
            added = true
        } catch (error: Throwable) {
            if (isCancellation(error)) throw error
            refusals += 1
            actionError = reportError(error)
        }
    }

    /** The capsule pressed again: the edition leaves the shelf. */
    suspend fun undoAdd() {
        try {
            bookAdded?.let { client.deleteBook(it) }
            bookAdded = null
            taken = null
            added = false
        } catch (error: Throwable) {
            if (isCancellation(error)) throw error
            refusals += 1
            actionError = reportError(error)
        }
    }

    /** "Envies": onto the wishlist, or off it again. */
    suspend fun toggleWish() {
        try {
            val id = wishId
            if (id != null) {
                client.removeWish(id)
                wishId = null
                isWished = false
            } else {
                wishId = client.wish(edition.draft(shown), Wish.Origin.DISCOVERY, null)
                isWished = true
            }
        } catch (error: Throwable) {
            if (isCancellation(error)) throw error
            refusals += 1
            actionError = reportError(error)
        }
    }
}

/**
 * An awaited edition, connected: opened from the home page, Actu, the wishlist, an author's page or
 * a book's. Describes it as it opens. Giving it up is the opener's when it holds the list the
 * edition leaves and passes `onStop`; otherwise the screen gives it up itself, and the lists read it
 * again on the notice the call posts.
 */
@Composable
fun AwaitedEditionScreen(
    edition: AwaitedEdition,
    client: DiscoverClient = DiscoverClient.live,
    coverClient: ReleaseCoverClient = ReleaseCoverClient.live,
    onStop: (() -> Unit)? = null,
) {
    val viewModel = remember(edition.id) { AwaitedEditionViewModel(edition, client) }
    val navigator = currentNavigator
    var choosesCover by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { viewModel.describe() }
    LaunchedEffect(Unit) { viewModel.loadSaga() }
    AwaitedEditionPage(
        edition = viewModel.edition,
        shown = viewModel.shown,
        isDescribing = viewModel.isDescribing,
        added = viewModel.added,
        taken = viewModel.taken,
        refusals = viewModel.refusals,
        sagaVolumes = viewModel.sagaVolumes,
    ) { action ->
        when (action) {
            AwaitedEditionAction.Close -> navigator.pop()
            is AwaitedEditionAction.Add -> viewModel.add(action.addition)
            AwaitedEditionAction.UndoAdd -> viewModel.undoAdd()
            AwaitedEditionAction.StopAwaiting -> if (onStop != null) {
                onStop()
                navigator.pop()
            } else if (viewModel.stopAwaiting()) {
                navigator.pop()
            }
            is AwaitedEditionAction.OpenVolume -> navigator.push { BookScreen(action.book.id) }
            is AwaitedEditionAction.OpenLacking -> viewModel.lackingSaga?.let { saga -> navigator.push { AnnouncedVolumeScreen(saga, action.volume) } }
            is AwaitedEditionAction.OpenSaga -> navigator.push { SeriesScreen(action.seriesId) }
            AwaitedEditionAction.ChooseCover -> choosesCover = true
        }
    }
    if (choosesCover) {
        ReleaseCoverPicker(viewModel.shown, viewModel.releaseKey, onDismiss = { choosesCover = false }, client = coverClient, onChosen = viewModel::drawCover)
    }
    viewModel.actionError?.let { ShioriAlert(L("Action impossible"), it, onDismiss = { viewModel.actionError = null }) }
}
