package com.polyforms.shiori.features.discover.components.pages

import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.tooling.preview.Preview
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.features.discover.DiscoveryVolume
import com.polyforms.shiori.features.discover.book
import com.polyforms.shiori.features.series.components.organisms.amazonURL
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.DiscoveredVolume
import com.polyforms.shiori.shared.ReleaseDateText
import com.polyforms.shiori.shared.SeriesStripItem
import com.polyforms.shiori.shared.book.BookState
import com.polyforms.shiori.shared.components.molecules.TakenState
import kotlinx.coroutines.launch

/** Everything an announced volume's page can ask for. */
sealed interface AnnouncedVolumeAction {
    data object Close : AnnouncedVolumeAction

    /** On the pile, read already or on the wishlist, filed in its saga at its number. */
    data class Add(val addition: UnownedBookAddition) : AnnouncedVolumeAction

    /** The "+"'s capsule pressed again: off the shelf. */
    data object UndoAdd : AnnouncedVolumeAction

    /** "Envies": onto the wishlist, or off it. */
    data object ToggleWish : AnnouncedVolumeAction
    data object OpenSaga : AnnouncedVolumeAction

    /** The saga's alerts on or off, from the bell. */
    data object ToggleFollowed : AnnouncedVolumeAction

    /** One of the reader's own volumes in the saga's row. */
    data class OpenVolume(val book: Book) : AnnouncedVolumeAction

    /** A volume of the saga the reader lacks, in the saga's row. */
    data class OpenLacking(val volume: DiscoveredVolume) : AnnouncedVolumeAction

    /** Another cover picked for it, for every reader. */
    data object ChooseCover : AnnouncedVolumeAction
}

/**
 * A volume announced, opened from Actu, the home page or its saga, drawn as a book not in the
 * library is ([UnownedBookPage]): the reader's own book page, its day pinned in the hero's corner.
 * It opens at once on what the look on the web found, then fills in as a book's page once the model
 * described it, for every reader at once. The bell is the saga's: it alerts on every volume's day.
 */
@Composable
fun AnnouncedVolumePage(
    opened: DiscoveryVolume,
    /** The book once described, or as the look on the web knows it until then. */
    shown: Book,
    isDescribing: Boolean,
    added: Boolean,
    /** Whether the saga's row leads to its page. Not when opened from the saga's page: the row leads back. */
    linksToSaga: Boolean,
    isFollowed: Boolean = true,
    taken: TakenState? = null,
    isWished: Boolean = false,
    refusals: Int = 0,
    sagaVolumes: List<SeriesStripItem> = emptyList(),
    onAction: suspend (AnnouncedVolumeAction) -> Unit,
) {
    val scope = rememberCoroutineScope()
    fun act(action: AnnouncedVolumeAction) {
        scope.launch { onAction(action) }
    }
    val series = opened.saga.series
    // Where it is ordered: its recording on Audible for a saga heard, once Audible confirmed it; Amazon for anything else.
    val store = if (series.isAudio) {
        opened.volume.audibleURL?.let { UnownedBookStore(it, isAudible = true) }
    } else {
        UnownedBookStore(opened.volume.amazonURL(series.author ?: ""), isAudible = false)
    }
    // Said on the detail line only when the calendar leaf does not say it: once added, once out, or with no date yet.
    val state = when {
        added -> BookState.addedToPile
        opened.volume.date?.let { ReleaseDateText.isUpcoming(it) } == true -> null
        else -> BookState.release(opened.volume.date)
    }
    UnownedBookPage(
        book = shown,
        releaseDate = opened.volume.date,
        store = store,
        isAlerted = isFollowed,
        onToggleBell = { act(AnnouncedVolumeAction.ToggleFollowed) },
        isDescribing = isDescribing,
        state = state,
        isAdded = added,
        sagaName = series.name,
        sagaVolumes = sagaVolumes,
        additions = listOf(UnownedBookAddition.PILE, UnownedBookAddition.READ),
        onAdd = { onAction(AnnouncedVolumeAction.Add(it)) },
        isWished = isWished,
        onToggleWish = { onAction(AnnouncedVolumeAction.ToggleWish) },
        taken = taken,
        onUndo = { onAction(AnnouncedVolumeAction.UndoAdd) },
        refusals = refusals,
        onOpenSaga = { act(if (linksToSaga) AnnouncedVolumeAction.OpenSaga else AnnouncedVolumeAction.Close) },
        onOpenVolume = { act(AnnouncedVolumeAction.OpenVolume(it)) },
        onOpenLacking = { act(AnnouncedVolumeAction.OpenLacking(it)) },
        onChooseCover = { act(AnnouncedVolumeAction.ChooseCover) },
    )
}

@Preview(showBackground = true)
@Composable
private fun AnnouncedVolumePagePreview() = PreviewSurface {
    val opened = DiscoveryVolume(DebugFixtures.sagas[0], DebugFixtures.announcedVolume)
    AnnouncedVolumePage(opened, opened.book, isDescribing = true, added = false, linksToSaga = true) {}
}
