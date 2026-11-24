package com.polyforms.shiori.features.discover

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import com.polyforms.shiori.features.book.BookScreen
import com.polyforms.shiori.features.discover.components.pages.AnnouncedVolumeAction
import com.polyforms.shiori.features.discover.components.pages.AnnouncedVolumePage
import com.polyforms.shiori.features.discover.components.pages.UnownedBookAddition
import com.polyforms.shiori.features.series.SeriesScreen
import com.polyforms.shiori.features.wishlist.Wish
import com.polyforms.shiori.shared.ApiError
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.DiscoveredVolume
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.SeriesStripItem
import com.polyforms.shiori.shared.components.molecules.TakenState
import com.polyforms.shiori.shared.isCancellation
import com.polyforms.shiori.shared.platform.ShioriAlert
import com.polyforms.shiori.shared.platform.currentNavigator
import com.polyforms.shiori.shared.reportError
import kotlinx.coroutines.launch

/** A volume announced or just out: its description, its saga's row, the saga's alerts, and its addition to the pile. */
class AnnouncedVolumeViewModel(val opened: DiscoveryVolume, private val client: DiscoverClient) {
    private val describer = ReleaseDescriber(opened.release) {
        client.describe(ReleaseItem.SagaVolume(opened.saga.series.seriesId, opened.volume.number))
    }

    var added by mutableStateOf(false)
        private set

    /** What the "+" made of the volume, said in its capsule. */
    var taken by mutableStateOf<TakenState?>(null)
        private set

    /** On the wishlist, from "Envies". */
    var isWished by mutableStateOf(false)
        private set

    /** Bumped on each refusal: the hero's buttons shake. */
    var refusals by mutableStateOf(0)
        private set

    /** The book put on the shelf and the wish made here, which a second tap takes back. */
    private var bookAdded: String? = null
    private var wishId: String? = null

    /** Whether the saga alerts on its volumes' days: turned at once on a tap, the call made behind it. */
    var isFollowed by mutableStateOf(true)
        private set

    /** The saga's volumes, held or lacking, for the row on the page. */
    var sagaVolumes by mutableStateOf<List<SeriesStripItem>>(emptyList())
        private set

    /** Why the addition failed, for the alert; null once read. */
    var addFailed by mutableStateOf<String?>(null)

    /** The volume as its list drew it, then as the server described it. */
    val shown: Book get() = opened.book(describer.release)
    val isDescribing: Boolean get() = describer.isDescribing

    /** The release the page shows: its cover is picked for every reader. */
    val releaseKey: String get() = describer.release.key

    /** The cover picked for it, drawn at once. */
    fun drawCover(url: String) = describer.drawCover(url)

    suspend fun describe() = describer.describe()

    /** The saga's row, read off the catalogue already built. Nothing when it fails. */
    suspend fun loadSaga() {
        val series = opened.saga.series
        sagaVolumes = runCatching { client.sagaVolumes(series.seriesId, series.language) }.getOrNull() ?: return
    }

    /** The bell turns at once; a refusal turns it back. */
    suspend fun toggleFollowed() {
        val followed = !isFollowed
        isFollowed = followed
        try {
            client.setSagaFollowed(opened.saga.series.seriesId, followed)
        } catch (error: Throwable) {
            if (isCancellation(error)) throw error
            reportError(error)
            if (isFollowed == followed) isFollowed = !followed
        }
    }

    /**
     * Onto the pile, filed in its saga at its number, or read already, or on the wishlist. A
     * recording is best put on the pile through the reader's Audible account; without one, or when
     * Audible sells none, it is added from its page, as a printed volume is.
     */
    suspend fun add(addition: UnownedBookAddition = UnownedBookAddition.PILE) {
        val series = opened.saga.series
        if (addition == UnownedBookAddition.WISHLIST) return toggleWish()
        val state = if (addition == UnownedBookAddition.READ) TakenState.Read(series.isAudio) else TakenState.ToRead(series.isAudio)
        if (addition == UnownedBookAddition.PILE && series.isAudio) {
            try {
                bookAdded = client.addAudibleVolume(series.seriesId, opened.volume.number)
                took(state)
                return
            } catch (error: Throwable) {
                if (isCancellation(error)) throw error
                val code = (error as? ApiError)?.domainCode
                if (code != "NOT_FOUND" && code != "AUDIBLE_NOT_CONNECTED") reportError(error)
            }
        }
        try {
            var draft = opened.draft(shown)
            if (addition == UnownedBookAddition.READ) draft = draft.copy(status = ReadingStatus.READ)
            bookAdded = client.addSuggestion(draft)
            took(state)
        } catch (error: Throwable) {
            if (isCancellation(error)) throw error
            refusals += 1
            addFailed = reportError(error)
        }
    }

    /** The capsule pressed again: the volume leaves the shelf. */
    suspend fun undoAdd() {
        try {
            bookAdded?.let { client.deleteBook(it) }
            bookAdded = null
            taken = null
            added = false
        } catch (error: Throwable) {
            if (isCancellation(error)) throw error
            refusals += 1
            addFailed = reportError(error)
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
                wishId = client.wish(opened.draft(shown), Wish.Origin.DISCOVERY, null)
                isWished = true
            }
        } catch (error: Throwable) {
            if (isCancellation(error)) throw error
            refusals += 1
            addFailed = reportError(error)
        }
    }

    private fun took(state: TakenState) {
        taken = state
        added = true
    }
}

/**
 * A volume announced, connected: opened from Actu, the home page, or its row on the saga screen.
 * Describes it as it opens, lays out its saga's row, adds it, turns the saga's alerts on or off, and
 * pushes its saga or one of the reader's volumes. `linksToSaga` is false when it was opened from
 * the saga screen, which is right under it.
 */
@Composable
fun AnnouncedVolumeScreen(
    saga: SagaDiscovery,
    volume: DiscoveredVolume,
    linksToSaga: Boolean = true,
    client: DiscoverClient = DiscoverClient.live,
    coverClient: ReleaseCoverClient = ReleaseCoverClient.live,
) {
    val viewModel = remember(saga.id, volume.number) { AnnouncedVolumeViewModel(DiscoveryVolume(saga, volume), client) }
    val navigator = currentNavigator
    val scope = rememberCoroutineScope()
    var choosesCover by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { viewModel.describe() }
    LaunchedEffect(Unit) { viewModel.loadSaga() }
    AnnouncedVolumePage(
        opened = viewModel.opened,
        shown = viewModel.shown,
        isDescribing = viewModel.isDescribing,
        added = viewModel.added,
        linksToSaga = linksToSaga,
        isFollowed = viewModel.isFollowed,
        taken = viewModel.taken,
        isWished = viewModel.isWished,
        refusals = viewModel.refusals,
        sagaVolumes = viewModel.sagaVolumes,
    ) { action ->
        when (action) {
            AnnouncedVolumeAction.Close -> navigator.pop()
            AnnouncedVolumeAction.ChooseCover -> choosesCover = true
            is AnnouncedVolumeAction.Add -> viewModel.add(action.addition)
            AnnouncedVolumeAction.UndoAdd -> viewModel.undoAdd()
            AnnouncedVolumeAction.ToggleWish -> viewModel.toggleWish()
            AnnouncedVolumeAction.OpenSaga -> navigator.push { SeriesScreen(saga.series.seriesId) }
            AnnouncedVolumeAction.ToggleFollowed -> scope.launch { viewModel.toggleFollowed() }
            is AnnouncedVolumeAction.OpenVolume -> navigator.push { BookScreen(action.book.id) }
            is AnnouncedVolumeAction.OpenLacking -> navigator.push { AnnouncedVolumeScreen(saga, action.volume, linksToSaga) }
        }
    }
    if (choosesCover) {
        ReleaseCoverPicker(viewModel.shown, viewModel.releaseKey, onDismiss = { choosesCover = false }, client = coverClient, onChosen = viewModel::drawCover)
    }
    viewModel.addFailed?.let { ShioriAlert(L("Ajout impossible"), it, onDismiss = { viewModel.addFailed = null }) }
}
