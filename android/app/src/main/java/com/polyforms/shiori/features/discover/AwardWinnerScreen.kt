package com.polyforms.shiori.features.discover

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.polyforms.shiori.features.discover.components.organisms.DiscoveryChoice
import com.polyforms.shiori.features.discover.components.organisms.DiscoveryChoices
import com.polyforms.shiori.features.discover.components.organisms.taken
import com.polyforms.shiori.features.discover.components.pages.AwardWinnerAction
import com.polyforms.shiori.features.discover.components.pages.AwardWinnerPage
import com.polyforms.shiori.features.wishlist.Wish
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.isCancellation
import com.polyforms.shiori.shared.platform.ShioriAlert
import com.polyforms.shiori.shared.platform.currentNavigator
import com.polyforms.shiori.shared.reportError

/** An award winner's page: its description, asked for when it opens, and what the reader decides about it. */
class AwardWinnerViewModel(val winner: AwardWinner, private val client: DiscoverClient) {
    // A winner read back from a snapshot saved before its key was sent is not described: its page
    // stays the one its list drew.
    private val item = winner.key?.let { ReleaseItem.AwardWinner(it, winner.format) }
    private val describer = ReleaseDescriber(if (item == null) winner.release.copy(described = true) else winner.release) {
        client.describe(item ?: throw kotlinx.coroutines.CancellationException())
    }

    /** The winner as its list drew it, then as the server described it. */
    val shown: Book get() = describer.release.book("award-${winner.id}")
    val isDescribing: Boolean get() = describer.isDescribing
    val releaseKey: String get() = describer.release.key

    fun drawCover(url: String) = describer.drawCover(url)

    suspend fun describe() = describer.describe()

    /** The book said read, put on the pile, the wish made and the editions awaited here, which their capsule takes back. */
    private var bookRead: String? = null
    private var wishId: String? = null
    private var bookAdded: String? = null
    private val awaitedIds = mutableMapOf<ReleaseFormat, String>()

    /** Why a choice could not be made, said in an alert. */
    var actionError by mutableStateOf<String?>(null)

    /** A choice from the page's "+" or eye, the page staying open on it. Says whether the server took it. */
    suspend fun choose(winner: AwardWinner, choice: DiscoveryChoice): Boolean = try {
        when (choice) {
            is DiscoveryChoice.Add -> bookAdded = client.addSuggestion(winner.pileDraft.taken(choice.format, ReadingStatus.TO_READ))
            is DiscoveryChoice.Await -> awaitedIds[choice.format] = client.awaitEdition(winner.draft, choice.format).id
            is DiscoveryChoice.AlreadyRead -> bookRead = client.addSuggestion(winner.pileDraft.taken(choice.format, ReadingStatus.READ))
            DiscoveryChoice.Wish -> wishId = client.wish(winner.pileDraft, Wish.Origin.AWARD, winner.mentions.firstOrNull()?.award?.displayName)
            DiscoveryChoice.Unwish -> {
                wishId?.let { client.removeWish(it) }
                wishId = null
            }
            DiscoveryChoice.UndoAlreadyRead -> {
                bookRead?.let { client.deleteBook(it) }
                bookRead = null
            }
            DiscoveryChoice.UndoAdd -> {
                bookAdded?.let { client.deleteBook(it) }
                bookAdded = null
            }
            is DiscoveryChoice.Unawait -> {
                // Awaited here, or already when the page opened.
                val id = awaitedIds[choice.format] ?: if (winner.format == choice.format) winner.awaitedEditionId else null
                id?.let { client.stopAwaiting(it) }
                awaitedIds.remove(choice.format)
            }
            DiscoveryChoice.NotInterested -> winner.key?.let { client.dismissWinner(it) }
            DiscoveryChoice.Reconsider -> winner.key?.let { client.reconsiderWinner(it) }
        }
        true
    } catch (error: Throwable) {
        if (isCancellation(error)) throw error
        actionError = reportError(error)
        false
    }
}

/**
 * An award winner, connected: opened from Actu or the home. Describes it as it opens; what the
 * reader decides stays on the page, which the opener's list catches up with once it closes.
 */
@Composable
fun AwardWinnerScreen(
    winner: AwardWinner,
    /** The winners listed beside it, for the row at the foot of its page. */
    others: List<AwardWinner> = emptyList(),
    client: DiscoverClient = DiscoverClient.live,
    coverClient: ReleaseCoverClient = ReleaseCoverClient.live,
) {
    val viewModel = remember(winner.id) { AwardWinnerViewModel(winner, client) }
    val choices = remember { DiscoveryChoices() }
    val navigator = currentNavigator
    var choosesCover by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { viewModel.describe() }
    AwardWinnerPage(
        winner = viewModel.winner,
        shown = viewModel.shown,
        isDescribing = viewModel.isDescribing,
        choices = choices,
        onChoice = viewModel::choose,
        others = others.filter { it.id != viewModel.winner.id },
    ) { action ->
        when (action) {
            AwardWinnerAction.Close -> navigator.pop()
            is AwardWinnerAction.OpenWinner -> navigator.push { AwardWinnerScreen(action.winner, others, client, coverClient) }
            AwardWinnerAction.ChooseCover -> choosesCover = true
        }
    }
    if (choosesCover) {
        ReleaseCoverPicker(viewModel.shown, viewModel.releaseKey, onDismiss = { choosesCover = false }, client = coverClient, onChosen = viewModel::drawCover)
    }
    viewModel.actionError?.let { ShioriAlert(L("Une erreur est survenue"), it, onDismiss = { viewModel.actionError = null }) }
}
