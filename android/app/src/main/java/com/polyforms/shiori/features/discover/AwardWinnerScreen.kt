package com.polyforms.shiori.features.discover

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.polyforms.shiori.R
import com.polyforms.shiori.features.book.BookApi
import com.polyforms.shiori.features.book.BookDraft
import com.polyforms.shiori.features.discover.components.organisms.DiscoveryButtons
import com.polyforms.shiori.features.discover.components.organisms.DiscoveryChoice
import com.polyforms.shiori.features.discover.components.organisms.DiscoveryChoices
import com.polyforms.shiori.features.wishlist.Wish
import com.polyforms.shiori.features.wishlist.WishlistApi
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
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
import com.polyforms.shiori.shared.components.molecules.GeneratingPillHost
import com.polyforms.shiori.shared.components.molecules.RowHeader
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable
import com.polyforms.shiori.shared.isCancellation
import com.polyforms.shiori.shared.platform.ScreenBar
import com.polyforms.shiori.shared.platform.ShioriAlert
import com.polyforms.shiori.shared.platform.currentNavigator
import com.polyforms.shiori.shared.reportError

/** The category an award crowns, as the laurels and the facts name it. */
val LiteraryAward.categoryName: String
    get() = when (this) {
        LiteraryAward.LOCUS_SCIENCE_FICTION -> L("Meilleur roman de SF")
        LiteraryAward.LOCUS_FANTASY -> L("Meilleur roman de fantasy")
        else -> L("Meilleur roman")
    }

/** An award winner the reader does not hold: described on the spot, the same buttons as its tile. */
class AwardWinnerViewModel(val winner: AwardWinner) {
    val describer = ReleaseDescriber()
    private var bookRead: String? = null
    var actionError by mutableStateOf<String?>(null)

    suspend fun choose(winner: AwardWinner, choice: DiscoveryChoice): Boolean = try {
        when (choice) {
            DiscoveryChoice.Add -> DiscoverViewModel.add(winner.pileDraft)
            is DiscoveryChoice.Await -> AwaitedApi.awaitScanned(winner.draft, choice.format)
            DiscoveryChoice.AlreadyRead -> bookRead = DiscoverViewModel.add(winner.pileDraft.copy(status = ReadingStatus.READ)).id
            DiscoveryChoice.Wish -> WishlistApi.wish(winner.pileDraft, Wish.Origin.AWARD, winner.mentions.firstOrNull()?.award?.displayName)
            DiscoveryChoice.UndoAlreadyRead -> {
                bookRead?.let { BookApi.delete(it) }
                bookRead = null
            }
            DiscoveryChoice.NotInterested -> winner.key?.let { AwardsApi.dismiss(it) }
            DiscoveryChoice.Reconsider -> winner.key?.let { AwardsApi.reconsider(it) }
        }
        true
    } catch (error: Throwable) {
        if (!isCancellation(error)) actionError = reportError(error)
        false
    }
}

/** A prize-winning novel: its laurels over the title, its facts, the other winners under it. */
@Composable
fun AwardWinnerScreen(winner: AwardWinner, others: List<AwardWinner> = emptyList()) {
    val viewModel = remember(winner.id) { AwardWinnerViewModel(winner) }
    val choices = remember { DiscoveryChoices() }
    val navigator = currentNavigator
    LaunchedEffect(Unit) { viewModel.describer.describe(winner.seed) }
    val shown = winner.cover.described(viewModel.describer.description)
    val state = when {
        winner.state == AwaitedState.ANNOUNCED && winner.date?.let { ReleaseDateText.isUpcoming(it) } == true -> BookState.release(winner.date)
        winner.watched -> BookState(winner.stateLine, winner.stateTint)
        else -> shown.firstPublishedIn?.let { BookState(it.toString(), SystemTint.GRAY) }
    }
    Box(Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground).verticalScroll(rememberScrollState())) {
            BookHero(
                shown,
                state = state,
                isAwaited = winner.awaitedEditionId != null,
                overTitle = winner.mentions.firstOrNull()?.let { mention -> { AwardLaurels(mention) } },
            ) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    DiscoveryButtons(winner, choices, viewModel::choose, addsInFull = true)
                }
            }
            Column(Modifier.fillMaxWidth().padding(top = 4.dp, bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(28.dp)) {
                Column(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(28.dp)) {
                    if (!viewModel.describer.isDescribing) shown.synopsis?.takeIf { it.isNotEmpty() }?.let { BookSynopsisBlock(it) }
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        RowHeader(L("Informations"))
                        val original = if (winner.title == winner.originalTitle) emptyList() else listOf(FactTile("originalTitle", L("Titre original"), winner.originalTitle, isWide = true))
                        val prize = winner.mentions.firstOrNull()?.let { first ->
                            listOf(FactTile("prize", L("Prix"), winner.mentionsLine, isWide = winner.mentions.size > 1), FactTile("category", L("Catégorie"), first.award.categoryName))
                        } ?: emptyList()
                        val order = listOf("publisher", "pageCount", "duration", "genre")
                        val facts = shown.readOnlyFactTiles.filter { it.id in order && it.value != null }.sortedBy { order.indexOf(it.id) }
                        val link = winner.storeURL?.let { url ->
                            if (winner.format == ReleaseFormat.AUDIOBOOK) FactLink("audible", L("Écouter sur Audible"), R.drawable.audible_logo, url) else FactLink("amazon", L("Voir sur Amazon"), R.drawable.amazon_logo, url)
                        }
                        FactGrid(listOf(FactGroup(original + prize + facts)), listOfNotNull(link))
                    }
                }
                val rest = others.filter { it.id != winner.id }
                if (rest.isNotEmpty()) {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        RowHeader(L("Autres lauréats"), Modifier.padding(horizontal = 20.dp))
                        LazyRow(contentPadding = PaddingValues(horizontal = 20.dp), horizontalArrangement = Arrangement.spacedBy(13.dp)) {
                            items(rest, key = { it.id }) { other ->
                                PosterCover(other.cover, other.caption, Modifier.plainClickable { navigator.push { AwardWinnerScreen(other, others) } })
                            }
                        }
                    }
                }
            }
        }
        ScreenBar()
        GeneratingPillHost(viewModel.describer.isDescribing)
    }
    viewModel.actionError?.let { ShioriAlert(L("Une erreur est survenue"), it, onDismiss = { viewModel.actionError = null }) }
}

/** The award between two laurels: its short name, the year, the category. */
@Composable
fun AwardLaurels(mention: AwardMention) {
    Row(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(Symbol("laurel.leading"), null, Modifier.size(44.dp), tint = Color.White)
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(1.dp)) {
            Text(mention.award.shortName.uppercase(), style = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp), color = Color.White)
            Text(mention.year.toString(), style = TextStyle(fontSize = 23.sp, fontWeight = FontWeight.ExtraBold), color = Color.White)
            Text(mention.award.categoryName, style = TextStyle(fontSize = 12.sp), color = Color.White.copy(alpha = 0.85f))
        }
        Icon(Symbol("laurel.trailing"), null, Modifier.size(44.dp), tint = Color.White)
    }
}
