package com.polyforms.shiori.features.discover

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.polyforms.shiori.features.book.BookScreen
import com.polyforms.shiori.features.book.BookDraft
import com.polyforms.shiori.features.discover.components.organisms.DiscoveryChoice
import com.polyforms.shiori.features.discover.components.organisms.DiscoveryChoices
import com.polyforms.shiori.features.discover.components.organisms.taken
import com.polyforms.shiori.features.discover.components.pages.SuggestionAction
import com.polyforms.shiori.features.discover.components.pages.SuggestionPage
import com.polyforms.shiori.features.series.SeriesScreen
import com.polyforms.shiori.features.wishlist.Wish
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.isCancellation
import com.polyforms.shiori.shared.platform.ShioriAlert
import com.polyforms.shiori.shared.platform.currentNavigator
import com.polyforms.shiori.shared.reportError

/** A suggestion's page: its description, asked for when it opens, and what the reader decides about it. */
class SuggestionViewModel(val suggestion: Suggestion, private val client: DiscoverClient) {
    private val describer = ReleaseDescriber(suggestion.release) {
        client.describe(ReleaseItem.Suggestion(suggestion.id, suggestion.format))
    }

    /** The suggestion as its list drew it, then as the server described it. */
    val shown: Book get() = describer.release.book("suggestion-${suggestion.id}")
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
    suspend fun choose(suggestion: Suggestion, choice: DiscoveryChoice): Boolean = try {
        when (choice) {
            is DiscoveryChoice.Add -> bookAdded = client.addSuggestion(suggestion.shelfDraft(ReadingStatus.TO_READ).taken(choice.format, ReadingStatus.TO_READ))
            is DiscoveryChoice.Await -> awaitedIds[choice.format] = client.awaitEdition(suggestion.draft, choice.format).id
            is DiscoveryChoice.AlreadyRead -> bookRead = client.addSuggestion(suggestion.shelfDraft(ReadingStatus.READ).taken(choice.format, ReadingStatus.READ))
            DiscoveryChoice.Wish -> wishId = client.wish(suggestion.shelfDraft(ReadingStatus.TO_READ), Wish.Origin.DISCOVERY, null)
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
                val id = awaitedIds[choice.format] ?: if (suggestion.format == choice.format) suggestion.awaitedEditionId else null
                id?.let { client.stopAwaiting(it) }
                awaitedIds.remove(choice.format)
            }
            DiscoveryChoice.NotInterested -> client.dismissSuggestion(suggestion.id, DismissalReason.NOT_INTERESTED)
            DiscoveryChoice.Reconsider -> client.reconsiderSuggestion(suggestion.id)
        }
        true
    } catch (error: Throwable) {
        if (isCancellation(error)) throw error
        actionError = reportError(error)
        false
    }

    /** The book as it goes onto the shelf. */
    fun draft(status: ReadingStatus): BookDraft = suggestion.shelfDraft(status)
}

/**
 * A suggestion, connected: opened from the home page. Describes it as it opens; what the reader
 * decides stays on the page, which the opener's line catches up with once it closes. `onChoice` is
 * the opener's own way of asking the server, the home's; null, the page's.
 */
@Composable
fun SuggestionScreen(
    suggestion: Suggestion,
    choices: DiscoveryChoices = remember { DiscoveryChoices() },
    onChoice: (suspend (Suggestion, DiscoveryChoice) -> Boolean)? = null,
    client: DiscoverClient = DiscoverClient.live,
    coverClient: ReleaseCoverClient = ReleaseCoverClient.live,
) {
    val viewModel = remember(suggestion.id) { SuggestionViewModel(suggestion, client) }
    val navigator = currentNavigator
    var choosesCover by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { viewModel.describe() }
    SuggestionPage(
        suggestion = viewModel.suggestion,
        shown = viewModel.shown,
        isDescribing = viewModel.isDescribing,
        choices = choices,
        onChoice = onChoice ?: viewModel::choose,
    ) { action ->
        when (action) {
            SuggestionAction.Close -> navigator.pop()
            // A saga cited by name opens the saga's page; a book, its own.
            is SuggestionAction.OpenReference -> {
                val reference = action.reference
                val seriesId = reference.seriesId
                navigator.push { if (reference.citesSaga && seriesId != null) SeriesScreen(seriesId) else BookScreen(reference.bookId) }
            }
            SuggestionAction.ChooseCover -> choosesCover = true
        }
    }
    if (choosesCover) {
        ReleaseCoverPicker(viewModel.shown, viewModel.releaseKey, onDismiss = { choosesCover = false }, client = coverClient, onChosen = viewModel::drawCover)
    }
    viewModel.actionError?.let { ShioriAlert(L("Une erreur est survenue"), it, onDismiss = { viewModel.actionError = null }) }
}
