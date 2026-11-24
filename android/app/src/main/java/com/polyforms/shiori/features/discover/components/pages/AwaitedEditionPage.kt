package com.polyforms.shiori.features.discover.components.pages

import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.tooling.preview.Preview
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.features.discover.AwaitedEdition
import com.polyforms.shiori.features.discover.AwaitedState
import com.polyforms.shiori.features.discover.ReleaseFormat
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.DiscoveredVolume
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReleaseDateText
import com.polyforms.shiori.shared.SeriesStripItem
import com.polyforms.shiori.shared.SystemTint
import com.polyforms.shiori.shared.book.BookState
import com.polyforms.shiori.shared.book.FactTile
import com.polyforms.shiori.shared.components.molecules.TakenState
import kotlinx.coroutines.launch

/** Everything an awaited edition's page can ask for. */
sealed interface AwaitedEditionAction {
    data object Close : AwaitedEditionAction

    /** On the pile, filed in the saga of the reader's copy, or read already. */
    data class Add(val addition: UnownedBookAddition) : AwaitedEditionAction

    /** The "+"'s capsule pressed again: off the shelf. */
    data object UndoAdd : AwaitedEditionAction

    /** Given up, by the bell once confirmed or by "Retirer": the page closes behind it. */
    data object StopAwaiting : AwaitedEditionAction

    /** The reader's copy, or another of their volumes, in the saga's row. */
    data class OpenVolume(val book: Book) : AwaitedEditionAction
    data class OpenSaga(val seriesId: String) : AwaitedEditionAction

    /** A volume of the saga the reader lacks, in the saga's row. */
    data class OpenLacking(val volume: DiscoveredVolume) : AwaitedEditionAction

    /** Another cover picked for it, for every reader. */
    data object ChooseCover : AwaitedEditionAction
}

/**
 * One awaited edition — a translation or a recording of a book the reader holds — drawn as a book
 * to come is ([UnownedBookPage]): the reader's own book page, its day pinned in the hero's corner,
 * the saga of their copy under it, their copy ringed. The bell gives the wait up, asked first, and
 * "Retirer" once the edition is out and nothing is left to alert on. No "Envies": an edition awaited
 * is on the wish list already, and "Retirer" takes it off, ending the wait with it.
 */
@Composable
fun AwaitedEditionPage(
    edition: AwaitedEdition,
    /** The edition once described, as a book's page draws it. */
    shown: Book,
    isDescribing: Boolean,
    added: Boolean = false,
    taken: TakenState? = null,
    refusals: Int = 0,
    sagaVolumes: List<SeriesStripItem> = emptyList(),
    onAction: suspend (AwaitedEditionAction) -> Unit,
) {
    val scope = rememberCoroutineScope()
    fun act(action: AwaitedEditionAction) {
        scope.launch { onAction(action) }
    }
    // Said on the detail line only when the calendar leaf does not say it: once out, or announced with no date.
    val state = when {
        added -> BookState.addedToPile
        edition.state == AwaitedState.UNANNOUNCED -> null
        edition.state == AwaitedState.ANNOUNCED && edition.date?.let { ReleaseDateText.isUpcoming(it) } == true -> null
        else -> BookState(edition.stateLine, edition.stateTint ?: SystemTint.GRAY)
    }
    UnownedBookPage(
        book = shown,
        releaseDate = edition.date,
        store = edition.storeURL?.let { UnownedBookStore(it, isAudible = edition.format == ReleaseFormat.AUDIOBOOK) },
        isAlerted = true,
        onToggleBell = { act(AwaitedEditionAction.StopAwaiting) },
        isDescribing = isDescribing,
        bellConfirmation = BellConfirmation(L("Ne plus suivre ce livre ?"), L("Vous ne serez plus prévenu de sa sortie."), L("Ne plus suivre")),
        state = state,
        stateTag = if (edition.state == AwaitedState.UNANNOUNCED && !added) L("Pas annoncé") else null,
        isOut = edition.state == AwaitedState.AVAILABLE,
        isAdded = if (edition.isAddable) added else null,
        // Its title in its own language, heading the facts when the edition translates it.
        leadingTiles = if (edition.title == edition.originalTitle) emptyList() else listOf(FactTile("originalTitle", L("Titre original"), edition.originalTitle, isWide = true)),
        sagaName = shown.series?.name,
        sagaVolumes = sagaVolumes,
        currentVolumeId = edition.bookId,
        additions = listOf(UnownedBookAddition.PILE, UnownedBookAddition.READ),
        onAdd = { onAction(AwaitedEditionAction.Add(it)) },
        taken = taken,
        onUndo = { onAction(AwaitedEditionAction.UndoAdd) },
        refusals = refusals,
        onOpenSaga = { shown.series?.id?.let { act(AwaitedEditionAction.OpenSaga(it)) } },
        onOpenVolume = { act(AwaitedEditionAction.OpenVolume(it)) },
        onOpenLacking = { act(AwaitedEditionAction.OpenLacking(it)) },
        // Once out, no bell is left to give the wait up: the button says it.
        onNoLongerInterested = { onAction(AwaitedEditionAction.StopAwaiting) },
        onChooseCover = { act(AwaitedEditionAction.ChooseCover) },
        recommendedBy = edition.recommendedBy,
    )
}

@Preview(showBackground = true)
@Composable
private fun AwaitedEditionPagePreview() = PreviewSurface {
    val edition = DebugFixtures.discoverAwaited[0].copy(recommendedBy = "Léa")
    AwaitedEditionPage(edition, edition.cover, isDescribing = false) {}
}
