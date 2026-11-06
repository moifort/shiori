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
import androidx.compose.ui.platform.LocalContext
import com.polyforms.shiori.features.friends.components.pages.FriendProfileAction
import com.polyforms.shiori.features.friends.components.pages.FriendProfilePage
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.SnapshotCache
import com.polyforms.shiori.shared.isCancellation
import com.polyforms.shiori.shared.platform.MenuEntry
import com.polyforms.shiori.shared.platform.ScreenBar
import com.polyforms.shiori.shared.platform.ToolbarMenuButton
import com.polyforms.shiori.shared.platform.copyText
import com.polyforms.shiori.shared.platform.currentNavigator
import com.polyforms.shiori.shared.platform.shareText
import com.polyforms.shiori.shared.reportError
import com.polyforms.shiori.shared.components.styles.Shiori
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * One friend's shelf, summed up — or the reader's own, previewed from the shelf already in hand.
 * The page opens on the shelf it showed last time, kept on disk per friend.
 */
class FriendProfileViewModel(val friend: Friend, private val client: FriendsClient, private val scope: CoroutineScope, preview: FriendProfile? = null) {
    /** The reader's own page as their friends see it: nothing is asked of the server. */
    val isPreview = preview != null
    private val cache = if (preview == null) SnapshotCache("friend-${friend.userId}", 1, FriendProfile.serializer()) else null

    var profile by mutableStateOf(preview ?: cache?.read())
        private set
    var isLoading by mutableStateOf(preview == null)
        private set

    /** Only drawn when there is no shelf on screen. */
    var errorMessage by mutableStateOf<String?>(null)
        private set

    suspend fun load() {
        if (isPreview) return
        isLoading = true
        try {
            profile = client.profile(friend.userId)
            errorMessage = null
            write()
        } catch (error: Throwable) {
            if (!isCancellation(error)) {
                val message = reportError(error)
                if (profile == null) errorMessage = message
            }
        }
        isLoading = false
    }

    /** The book is the reader's now: every shelf of the page says so. */
    fun markOwned(bookId: String) {
        profile = profile?.markingOwned(bookId) ?: return
        write()
    }

    private fun write() {
        val cache = cache ?: return
        val profile = profile ?: return
        scope.launch(Dispatchers.IO) { cache.write(profile) }
    }
}

/** One friend's shelf, connected: pushes a book and the whole library. */
@Composable
fun FriendProfileScreen(friend: Friend, preview: FriendProfile? = null, client: FriendsClient = FriendsClient.live) {
    val scope = rememberCoroutineScope()
    val viewModel = remember(friend.userId) { FriendProfileViewModel(friend, client, scope, preview) }
    val navigator = currentNavigator
    val context = LocalContext.current
    LaunchedEffect(Unit) { viewModel.load() }
    Box(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground)) {
        FriendProfilePage(friend, viewModel.profile, viewModel.isPreview, viewModel.isLoading, viewModel.errorMessage) { action ->
            when (action) {
                is FriendProfileAction.OpenBook -> navigator.push {
                    FriendBookScreen(friend.userId, action.book.id, friend.displayName, onAdded = { viewModel.markOwned(action.book.id) })
                }
                FriendProfileAction.OpenLibrary -> navigator.push { FriendShelfScreen(friend.userId, friend.displayName, viewModel.isPreview) }
                FriendProfileAction.Refresh -> viewModel.load()
            }
        }
        ScreenBar(viewModel.profile?.displayName ?: friend.displayName) {
            // The preview keeps the whole list of favourites as text, to send or to copy.
            val text = viewModel.profile?.takeIf { viewModel.isPreview }?.let(FavoritesSharing::text)
            if (text != null) {
                ToolbarMenuButton(
                    L("Partager mes favoris"),
                    "square.and.arrow.up",
                    listOf(
                        MenuEntry.Item(L("Envoyer…"), "paperplane") { context.shareText(text) },
                        MenuEntry.Item(L("Copier la liste"), "doc.on.doc") { context.copyText(text) },
                    ),
                )
            }
        }
    }
}
