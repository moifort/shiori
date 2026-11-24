package com.polyforms.shiori.features.discover.components.pages

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
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.R
import com.polyforms.shiori.features.discover.AwaitedState
import com.polyforms.shiori.features.discover.AwardWinner
import com.polyforms.shiori.features.discover.DiscoverFixtures
import com.polyforms.shiori.features.discover.describedForPreview
import com.polyforms.shiori.features.discover.ReleaseFormat
import com.polyforms.shiori.features.discover.components.molecules.AwardLaurels
import com.polyforms.shiori.features.discover.components.molecules.categoryName
import com.polyforms.shiori.features.discover.components.organisms.DiscoveryButtons
import com.polyforms.shiori.features.discover.components.organisms.DiscoveryChoice
import com.polyforms.shiori.features.discover.components.organisms.DiscoveryChoices
import com.polyforms.shiori.features.discover.components.organisms.UnownedBookActionsMenu
import com.polyforms.shiori.features.series.components.organisms.SeriesPosterRail
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReleaseDateText
import com.polyforms.shiori.shared.SystemTint
import com.polyforms.shiori.shared.book.BookHero
import com.polyforms.shiori.shared.book.BookState
import com.polyforms.shiori.shared.book.BookSynopsisBlock
import com.polyforms.shiori.shared.book.FactGrid
import com.polyforms.shiori.shared.book.FactGroup
import com.polyforms.shiori.shared.book.FactLink
import com.polyforms.shiori.shared.book.FactTile
import com.polyforms.shiori.shared.book.PosterCover
import com.polyforms.shiori.shared.book.readOnlyFactTiles
import com.polyforms.shiori.shared.components.atoms.HeroStatus
import com.polyforms.shiori.shared.components.molecules.AddMenuSize
import com.polyforms.shiori.shared.components.molecules.GeneratingPillHost
import com.polyforms.shiori.shared.components.molecules.OwnedCapsule
import com.polyforms.shiori.shared.components.molecules.RowHeader
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.plainClickable
import com.polyforms.shiori.shared.platform.ScreenBar
import kotlinx.coroutines.launch

/** Everything an award winner's page can ask for. */
sealed interface AwardWinnerAction {
    data object Close : AwardWinnerAction

    /** Another winner, from the row at the foot of the page. */
    data class OpenWinner(val winner: AwardWinner) : AwardWinnerAction

    /** Another cover picked for it, for every reader. */
    data object ChooseCover : AwardWinnerAction
}

/**
 * One winner, in the suggestion's page's grammar: the hero over the cover's colours, the prize
 * between its laurels over the title and the white "+ Ajouter" and closed eye under it, then the
 * summary once written, the facts as tiles and the other winners as posters. "+ Ajouter" adds,
 * wishes for or awaits it, one action at a time; the eye turns it down, black and white. The page
 * stays open on the choice, which the same button takes back.
 */
@Composable
fun AwardWinnerPage(
    winner: AwardWinner,
    /** The winner once described, as a book's page draws it. */
    shown: Book,
    isDescribing: Boolean,
    choices: DiscoveryChoices,
    /** Asks the server, and says whether it took the choice. */
    onChoice: suspend (AwardWinner, DiscoveryChoice) -> Boolean,
    /** The winners listed beside it. */
    others: List<AwardWinner> = emptyList(),
    onAction: suspend (AwardWinnerAction) -> Unit,
) {
    val scope = rememberCoroutineScope()
    fun act(action: AwardWinnerAction) {
        scope.launch { onAction(action) }
    }
    val isTurnedDown = choices.isTurnedDown(winner)
    // Said on the detail line: when an edition announced comes out, where it stands once a reader
    // awaited it and it was looked up, else the year it came out.
    val state = when {
        winner.state == AwaitedState.ANNOUNCED && winner.date?.let { ReleaseDateText.isUpcoming(it) } == true -> BookState.release(winner.date)
        winner.watched -> if (winner.state == AwaitedState.UNANNOUNCED) null else BookState(winner.stateLine, winner.stateTint)
        else -> shown.firstPublishedIn?.let { BookState(it.toString(), SystemTint.GRAY) }
    }
    Box(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground)) {
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
            BookHero(
                shown,
                state = state,
                stateTag = if (winner.watched && winner.state == AwaitedState.UNANNOUNCED) L("Pas annoncé") else null,
                overTitle = winner.mentions.firstOrNull()?.let { mention -> { AwardLaurels(mention) } },
                status = if (isTurnedDown) HeroStatus.notInterested else null,
                isSetAside = isTurnedDown,
            ) {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    // Held already, in any format, and nothing chosen here: "Ajouté" says why no button is left.
                    if (winner.inLibrary == true && choices.mark(winner) == null) {
                        OwnedCapsule(size = AddMenuSize.PAGE)
                    } else {
                        DiscoveryButtons(winner, choices, onChoice, addsInFull = true)
                    }
                }
            }
            Column(
                Modifier.fillMaxWidth().padding(start = 20.dp, end = 20.dp, top = 4.dp, bottom = 32.dp),
                verticalArrangement = Arrangement.spacedBy(28.dp),
            ) {
                // The summary once the model wrote it; nothing while it writes, the bar saying so.
                if (!isDescribing) shown.synopsis?.takeIf { it.isNotEmpty() }?.let { BookSynopsisBlock(it) }
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    RowHeader(L("Informations"))
                    val original = if (winner.title == winner.originalTitle) emptyList() else listOf(FactTile("originalTitle", L("Titre original"), winner.originalTitle, isWide = true))
                    // The prizes it won, then what the first crowns. Several take the width.
                    val prize = winner.mentions.firstOrNull()?.let { first ->
                        listOf(FactTile("prize", L("Prix"), winner.mentionsLine, isWide = winner.mentions.size > 1), FactTile("category", L("Catégorie"), first.award.categoryName))
                    } ?: emptyList()
                    // The book's own facts, the ones the page's description fills in, and only once known.
                    val order = listOf("publisher", "pageCount", "duration", "genre")
                    val facts = shown.readOnlyFactTiles.filter { it.id in order && it.value != null }.sortedBy { order.indexOf(it.id) }
                    val link = winner.storeURL?.let { url ->
                        if (winner.format == ReleaseFormat.AUDIOBOOK) FactLink("audible", L("Écouter sur Audible"), R.drawable.audible_logo, url) else FactLink("amazon", L("Voir sur Amazon"), R.drawable.amazon_logo, url)
                    }
                    FactGrid(listOf(FactGroup(original + prize + facts)), listOfNotNull(link))
                }
                if (others.isNotEmpty()) {
                    SeriesPosterRail(L("Autres lauréats"), others, id = { it.id }) { other ->
                        PosterCover(other.cover, other.caption, Modifier.plainClickable { act(AwardWinnerAction.OpenWinner(other)) })
                    }
                }
            }
        }
        // The bar's buttons float over the page as it scrolls, as on a book's.
        ScreenBar {
            UnownedBookActionsMenu(onChooseCover = { act(AwardWinnerAction.ChooseCover) })
        }
        GeneratingPillHost(isDescribing)
    }
}

@Preview(showBackground = true)
@Composable
private fun AwardWinnerPagePreview() = PreviewSurface {
    val winner = DiscoverFixtures.awardWinner
    AwardWinnerPage(winner, winner.release.describedForPreview.book("award-preview"), isDescribing = false, remember { DiscoveryChoices() }, { _, _ -> true }, others = listOf(DiscoverFixtures.goncourtWinner)) {}
}
