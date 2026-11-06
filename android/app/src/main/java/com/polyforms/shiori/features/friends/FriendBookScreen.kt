package com.polyforms.shiori.features.friends

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.authors.AuthorScreen
import com.polyforms.shiori.features.discover.AwaitedEdition
import com.polyforms.shiori.features.discover.AwaitedEditionScreen
import com.polyforms.shiori.features.discover.EditionOffer
import com.polyforms.shiori.features.discover.ReleaseFormat
import com.polyforms.shiori.features.friends.components.pages.FriendBookAction
import com.polyforms.shiori.features.friends.components.pages.FriendBookPage
import com.polyforms.shiori.features.narrators.NarratorScreen
import com.polyforms.shiori.features.series.SeriesFriend
import com.polyforms.shiori.features.series.SeriesScreen
import com.polyforms.shiori.features.series.components.pages.takenAs
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.SnapshotCache
import com.polyforms.shiori.shared.account.AccountAvatar
import com.polyforms.shiori.shared.components.atoms.AccountAvatarView
import com.polyforms.shiori.shared.components.molecules.EmptyState
import com.polyforms.shiori.shared.components.molecules.FailureState
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.isCancellation
import com.polyforms.shiori.shared.platform.LoadingScreen
import com.polyforms.shiori.shared.platform.ScreenBar
import com.polyforms.shiori.shared.platform.ShioriAlert
import com.polyforms.shiori.shared.platform.currentNavigator
import com.polyforms.shiori.shared.reportError
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.launch

/**
 * A friend's book: the book itself, whether Audible sells it, what may be awaited of it in the
 * app's language, and what the reader took of it.
 */
class FriendBookViewModel(val friendId: String, val bookId: String, private val client: FriendsClient, private val scope: CoroutineScope) {
    private val cache = SnapshotCache("friend-book-$friendId-$bookId", 1, FriendBook.serializer())

    var entry by mutableStateOf(cache.read())
        private set
    var isLoading by mutableStateOf(true)
        private set
    var errorMessage by mutableStateOf<String?>(null)
        private set

    /** What the reader just did with it from the hero's first button. */
    var added by mutableStateOf<CopiedStatus?>(null)
        private set
    var wished by mutableStateOf(false)
        private set

    /** Whether Audible sells it: until it answers, the reader may still take it heard. */
    var audio by mutableStateOf<AudioAvailability?>(null)
        private set
    var offer by mutableStateOf(EditionOffer())
        private set
    var addFailed by mutableStateOf<String?>(null)

    /** The awaits sent and not answered yet: giving one up waits for the server's id. */
    private val awaiting = mutableMapOf<ReleaseFormat, Deferred<AwaitedEdition?>>()

    suspend fun load() {
        isLoading = true
        errorMessage = null
        try {
            val fetched = client.book(friendId, bookId)
            entry = fetched
            if (fetched != null) scope.launch(Dispatchers.IO) { cache.write(fetched) } else cache.forget()
        } catch (error: Throwable) {
            if (!isCancellation(error)) {
                val message = reportError(error)
                if (entry == null) errorMessage = message
            }
        }
        isLoading = false
    }

    suspend fun loadAudio() {
        try {
            audio = client.audio(friendId, bookId)
        } catch (error: Throwable) {
            if (!isCancellation(error)) reportError(error)
        }
    }

    suspend fun loadOffer() {
        try {
            offer = client.offer(friendId, bookId) ?: EditionOffer()
        } catch (error: Throwable) {
            if (!isCancellation(error)) reportError(error)
        }
    }

    /** Onto the reader's shelf, in the format they take it in. True once it is. */
    suspend fun add(status: CopiedStatus, format: BookFormat): Boolean = try {
        client.addBook(friendId, bookId, status, format)
        added = status
        true
    } catch (error: Throwable) {
        if (!isCancellation(error)) addFailed = reportError(error)
        false
    }

    suspend fun wish() {
        try {
            client.wish(friendId, bookId)
            wished = true
        } catch (error: Throwable) {
            if (!isCancellation(error)) addFailed = reportError(error)
        }
    }

    /** Shown awaited at once; the server's answer replaces the line when it comes. */
    fun awaitEdition(format: ReleaseFormat) {
        val book = entry?.book ?: return
        val pending = AwaitedEdition.pending(format, book)
        offer = offer.copy(awaited = offer.awaited + pending)
        awaiting[format] = scope.async {
            try {
                val edition = client.awaitEdition(friendId, bookId, format)
                // Unless the reader gave it up meanwhile.
                if (offer.awaited.any { it.id == pending.id }) offer = offer.copy(awaited = offer.awaited.map { if (it.id == pending.id) edition else it })
                edition
            } catch (error: Throwable) {
                offer = offer.copy(awaited = offer.awaited.filter { it.id != pending.id })
                if (!isCancellation(error)) addFailed = reportError(error)
                null
            } finally {
                awaiting.remove(format)
            }
        }
    }

    suspend fun stopAwaiting(edition: AwaitedEdition) {
        var target = edition
        awaiting[edition.format]?.let { pending ->
            offer = offer.copy(awaited = offer.awaited.filter { it.id != edition.id })
            target = pending.await() ?: return
        }
        try {
            client.stopAwaiting(target.id)
            offer = offer.copy(awaited = offer.awaited.filter { it.id != target.id })
        } catch (error: Throwable) {
            if (!isCancellation(error)) addFailed = reportError(error)
        }
    }
}

/**
 * A friend's book, connected: loads it, what Audible sells and what may be awaited of it, takes
 * it onto the reader's shelf from the hero's first button, pushes its saga.
 */
@Composable
fun FriendBookScreen(friendId: String, bookId: String, friendName: String, onAdded: () -> Unit = {}, client: FriendsClient = FriendsClient.live) {
    val scope = rememberCoroutineScope()
    val viewModel = remember(friendId, bookId) { FriendBookViewModel(friendId, bookId, client, scope) }
    val navigator = currentNavigator
    LaunchedEffect(Unit) { viewModel.load() }
    LaunchedEffect(Unit) { viewModel.loadAudio() }
    LaunchedEffect(Unit) { viewModel.loadOffer() }

    Box(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground)) {
        val entry = viewModel.entry
        val errorMessage = viewModel.errorMessage
        when {
            viewModel.isLoading && entry == null -> LoadingScreen()
            entry != null -> FriendBookPage(
                entry,
                friendName,
                viewModel.added,
                viewModel.offer.awaited,
                formats = entry.book.format.takenAs.filter { it != BookFormat.AUDIOBOOK || viewModel.audio != AudioAvailability.UNAVAILABLE },
                awaitable = viewModel.offer.awaitable,
                wished = viewModel.wished,
            ) { action ->
                when (action) {
                    FriendBookAction.OpenSeries -> entry.book.series?.let { series ->
                        navigator.push { SeriesScreen(series.id, friend = SeriesFriend(friendId, friendName)) }
                    }
                    // Offered as Découvrir offers a friend's loved author.
                    is FriendBookAction.OpenAuthor -> navigator.push { AuthorScreen(action.author.key, action.author.name, isOffered = true) }
                    is FriendBookAction.OpenNarrator -> navigator.push { NarratorScreen(action.narrator.key, action.narrator.name) }
                    is FriendBookAction.OpenAwaited -> navigator.push {
                        AwaitedEditionScreen(action.edition) { scope.launch { viewModel.stopAwaiting(action.edition) } }
                    }
                    is FriendBookAction.StopAwaiting -> viewModel.stopAwaiting(action.edition)
                    is FriendBookAction.Add -> if (viewModel.add(action.status, action.format)) onAdded()
                    is FriendBookAction.AwaitEdition -> viewModel.awaitEdition(action.format)
                    FriendBookAction.Wish -> viewModel.wish()
                }
            }
            errorMessage != null -> FailureState(L("Livre indisponible"), errorMessage) { viewModel.load() }
            else -> EmptyState("book.closed", L("Livre introuvable"), L("Ce livre n'est plus partagé."))
        }
        // Whose shelf it is: their disc in the corner, as an account's.
        ScreenBar {
            AccountAvatarView(entry?.ownerAvatar ?: AccountAvatar.Initials, friendName, 44.dp)
        }
    }
    viewModel.addFailed?.let { ShioriAlert(L("Ajout impossible"), it, onDismiss = { viewModel.addFailed = null }) }
}
