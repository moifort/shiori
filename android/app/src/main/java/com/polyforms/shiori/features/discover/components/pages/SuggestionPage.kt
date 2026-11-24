package com.polyforms.shiori.features.discover.components.pages

import com.polyforms.shiori.shared.platform.pageEndRoom
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.R
import com.polyforms.shiori.features.discover.AwaitedState
import com.polyforms.shiori.features.discover.ReleaseFormat
import com.polyforms.shiori.features.discover.Suggestion
import com.polyforms.shiori.features.discover.SuggestionReference
import com.polyforms.shiori.features.discover.components.organisms.DiscoveryButtons
import com.polyforms.shiori.features.discover.components.organisms.DiscoveryChoice
import com.polyforms.shiori.features.discover.components.organisms.DiscoveryChoices
import com.polyforms.shiori.features.discover.components.organisms.SuggestionReasonCard
import com.polyforms.shiori.features.discover.components.organisms.UnownedBookActionsMenu
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReleaseDateText
import com.polyforms.shiori.shared.book.BookHero
import com.polyforms.shiori.shared.book.BookState
import com.polyforms.shiori.shared.book.BookSynopsisBlock
import com.polyforms.shiori.shared.book.FactGrid
import com.polyforms.shiori.shared.book.FactGroup
import com.polyforms.shiori.shared.book.FactLink
import com.polyforms.shiori.shared.book.FactTile
import com.polyforms.shiori.shared.book.readOnlyFactTiles
import com.polyforms.shiori.shared.components.atoms.HeroStatus
import com.polyforms.shiori.shared.components.molecules.GeneratingPillHost
import com.polyforms.shiori.shared.components.molecules.RowHeader
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.platform.ScreenBar
import kotlinx.coroutines.launch

/** Everything a suggestion's page can ask for. */
sealed interface SuggestionAction {
    data object Close : SuggestionAction

    /** One of the reader's own books it was drawn from. */
    data class OpenReference(val reference: SuggestionReference) : SuggestionAction

    /** Another cover picked for it, for every reader. */
    data object ChooseCover : SuggestionAction
}

/**
 * A suggestion's page, in the reader's own book page's grammar: the hero over the cover's colours —
 * where its edition stands on the detail line, the white "Ajouter" and the closed eye under it —
 * then why it was chosen, as a card over the colours of the reader's books it draws on, the summary
 * once written, and the facts as tiles. "+ Ajouter" adds, wishes for or awaits it, one action at a
 * time; the eye turns it down, black and white. The page stays open on the choice, which the same
 * button takes back.
 */
@Composable
fun SuggestionPage(
    suggestion: Suggestion,
    /** The suggestion once described, as a book's page draws it. */
    shown: Book,
    isDescribing: Boolean,
    choices: DiscoveryChoices,
    /** Asks the server, and says whether it took the choice. */
    onChoice: suspend (Suggestion, DiscoveryChoice) -> Boolean,
    onAction: suspend (SuggestionAction) -> Unit,
) {
    val scope = rememberCoroutineScope()
    fun act(action: SuggestionAction) {
        scope.launch { onAction(action) }
    }
    val isTurnedDown = choices.isTurnedDown(suggestion)
    // Said on the detail line: when an edition announced comes out, or where it stands once a
    // reader awaited it and it was looked up. Nothing announced is a tag, beside the format's.
    val state = when {
        suggestion.state == AwaitedState.ANNOUNCED && suggestion.date?.let { ReleaseDateText.isUpcoming(it) } == true -> BookState.release(suggestion.date)
        !suggestion.watched || suggestion.state == AwaitedState.UNANNOUNCED -> null
        else -> BookState(suggestion.stateLine, suggestion.stateTint)
    }
    Box(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground)) {
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
            BookHero(
                shown,
                state = state,
                stateTag = if (suggestion.watched && suggestion.state == AwaitedState.UNANNOUNCED) L("Pas annoncé") else null,
                showsLength = false,
                status = if (isTurnedDown) HeroStatus.notInterested else null,
                isSetAside = isTurnedDown,
            ) {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    DiscoveryButtons(suggestion, choices, onChoice, addsInFull = true)
                }
            }
            Column(
                Modifier.fillMaxWidth().padding(start = 20.dp, end = 20.dp, top = 4.dp, bottom = pageEndRoom()),
                verticalArrangement = Arrangement.spacedBy(28.dp),
            ) {
                SuggestionReasonCard(suggestion.reason, suggestion.references) { act(SuggestionAction.OpenReference(it)) }
                // The summary once the model wrote it; nothing while it writes, the bar saying so.
                if (!isDescribing) shown.synopsis?.takeIf { it.isNotEmpty() }?.let { BookSynopsisBlock(it) }
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    RowHeader(L("Informations"))
                    val original = if (suggestion.title == suggestion.originalTitle) emptyList() else listOf(FactTile("originalTitle", L("Titre original"), suggestion.originalTitle, isWide = true))
                    val link = suggestion.storeURL?.let { url ->
                        if (suggestion.format == ReleaseFormat.AUDIOBOOK) FactLink("audible", L("Écouter sur Audible"), R.drawable.audible_logo, url) else FactLink("amazon", L("Voir sur Amazon"), R.drawable.amazon_logo, url)
                    }
                    FactGrid(listOf(FactGroup(original + shown.readOnlyFactTiles)), listOfNotNull(link))
                }
            }
        }
        // The bar's buttons float over the page as it scrolls, as on a book's.
        ScreenBar {
            UnownedBookActionsMenu(onChooseCover = { act(SuggestionAction.ChooseCover) })
        }
        GeneratingPillHost(isDescribing)
    }
}

@Preview(showBackground = true)
@Composable
private fun SuggestionPagePreview() = PreviewSurface {
    val suggestion = DebugFixtures.discoveries.suggestions[0]
    SuggestionPage(suggestion, suggestion.cover, isDescribing = false, remember { DiscoveryChoices() }, { _, _ -> true }) {}
}
