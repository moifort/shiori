package com.polyforms.shiori.features.friends

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.polyforms.shiori.shared.DataChanges
import com.polyforms.shiori.shared.SnapshotCache
import com.polyforms.shiori.shared.isCancellation
import com.polyforms.shiori.shared.reportError
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import kotlinx.serialization.builtins.ListSerializer

/**
 * Owns the Amis tab: the friends, the ones the reader picked, and the rails drawn from their
 * shelves. Picking nobody shows every friend; each friend tapped narrows the page to the friends
 * picked, and tapping them again widens it back. A reader with a single friend has no "every
 * friend": that friend is the pick, and the page is theirs.
 *
 * The tab opens on what it last showed for the same pick: one snapshot per pick, read before a
 * byte is asked of the network, brought up to date silently underneath.
 *
 * [caching]: off in tests, which must neither read nor leave a snapshot on disk.
 */
class FriendsViewModel(private val client: FriendsClient, private val scope: CoroutineScope, private val caching: Boolean = true) {
    private val friendsCache = if (caching) SnapshotCache("friends-tab-friends", 1, ListSerializer(Friend.serializer())) else null

    var friends by mutableStateOf(friendsCache?.read() ?: emptyList())
        private set

    /** The friends picked, in the order tapped. Empty means every friend. */
    var selected by mutableStateOf<List<String>>(emptyList())
        private set
    var shelf by mutableStateOf(shelfCache(emptyList())?.read() ?: FriendsShelf())
        private set

    /** The reader's own shelf, for the page without a friend: what their friends will see of them. */
    var myShelf by mutableStateOf<FriendProfile?>(null)
        private set
    var isLoading by mutableStateOf(false)
        private set

    /** The server has answered at least once, so the page is no longer the snapshot. */
    var loaded by mutableStateOf(false)
        private set

    /** Nothing could be read. Only drawn when there is nothing else on screen. */
    var loadFailed by mutableStateOf<String?>(null)
        private set

    /** The invitation just created, shared the moment it comes back. */
    var invitation by mutableStateOf<FriendInvitation?>(null)
    var isInviting by mutableStateOf(false)
        private set
    var errorMessage by mutableStateOf<String?>(null)

    /** A reload in flight for an older pick is dropped when it lands. */
    private var generation = 0

    val hasNoFriend: Boolean get() = loaded && friends.isEmpty()
    val isEmpty: Boolean get() = friends.isEmpty() && shelf.isEmpty

    /** The friends the page shows: the ones picked, or the only friend, who stands picked. */
    val picked: List<String> get() = FriendsPick.shown(friends.map { it.userId }, selected)

    /** The one friend shown, whose library and series the rows open. */
    val soleFriend: Friend? get() = picked.singleOrNull()?.let { id -> friends.firstOrNull { it.userId == id } }

    suspend fun loadOnAppear() {
        if (loaded || isLoading) return
        load()
    }

    /** The friends and the rails for the current pick. A refresh that fails over a page already on screen says nothing. */
    suspend fun load() {
        isLoading = true
        generation += 1
        val current = generation
        val pick = selected
        try {
            val (newFriends, newShelf) = coroutineScope {
                val fetchedFriends = async { client.friends() }
                val fetchedShelf = async { client.friendsShelf(pick) }
                fetchedFriends.await() to fetchedShelf.await()
            }
            if (current != generation) return
            friends = newFriends
            selected = FriendsPick.kept(newFriends.map { it.userId }, selected)
            shelf = newShelf
            loaded = true
            loadFailed = null
            write(newFriends, newShelf, pick)
            if (newFriends.isEmpty()) loadMyShelf()
        } catch (error: Throwable) {
            if (isCancellation(error)) return
            val message = reportError(error)
            if (isEmpty) loadFailed = message
        } finally {
            if (current == generation) isLoading = false
        }
    }

    /** A friend's avatar tapped: picked, or let go when already picked. The pick's last rails show at once. */
    suspend fun toggle(friendId: String) {
        // The only friend cannot be let go: there is nobody else to show.
        if (friends.size < 2) return
        selected = if (friendId in selected) selected - friendId else selected + friendId
        shelfCache(selected)?.read()?.let { shelf = it }
        load()
    }

    /** One friend alone, asked for from another tab: the pick is that friend, whatever was picked before. */
    suspend fun show(only: String) {
        if (selected == listOf(only)) return
        selected = listOf(only)
        shelfCache(selected)?.read()?.let { shelf = it }
        load()
    }

    suspend fun invite() {
        isInviting = true
        try {
            invitation = client.invite()
        } catch (error: Throwable) {
            if (!isCancellation(error)) errorMessage = reportError(error)
        }
        isInviting = false
    }

    /**
     * Stops sharing with a friend, both ways. They leave the avatars and the pick at once; every
     * tab that shows friends is told to ask again, since the server answers no library change for it.
     */
    suspend fun remove(friendId: String) {
        try {
            client.remove(friendId)
            friends = friends.filter { it.userId != friendId }
            selected = FriendsPick.kept(friends.map { it.userId }, selected)
            DataChanges.post(null)
        } catch (error: Throwable) {
            if (!isCancellation(error)) errorMessage = reportError(error)
        }
    }

    private suspend fun loadMyShelf() {
        try {
            myShelf = client.myShelf()
        } catch (error: Throwable) {
            if (!isCancellation(error)) reportError(error)
        }
    }

    /** One file per pick, the friends sorted so the same pick finds its file whatever order they were tapped in. */
    private fun shelfCache(pick: List<String>): SnapshotCache<FriendsShelf>? {
        if (!caching) return null
        val key = if (pick.isEmpty()) "all" else pick.sorted().joinToString("-")
        return SnapshotCache("friends-tab-shelf-$key", 1, FriendsShelf.serializer())
    }

    private fun write(friends: List<Friend>, shelf: FriendsShelf, pick: List<String>) {
        val shelfCache = shelfCache(pick)
        scope.launch(Dispatchers.IO) {
            friendsCache?.write(friends)
            shelfCache?.write(shelf)
        }
    }
}

/** Who the Amis tab shows, as a rule apart from the screen. */
object FriendsPick {
    /** The friends picked, or the only friend, who stands picked since there is nobody to narrow them from. */
    fun shown(friendIds: List<String>, selected: List<String>): List<String> =
        if (friendIds.size == 1) friendIds else selected

    /**
     * The pick once the friends change: a friend gone drops out of it, and an only friend is
     * picked without being chosen, so a second one arriving later finds the page on everyone.
     */
    fun kept(friendIds: List<String>, selected: List<String>): List<String> =
        if (friendIds.size < 2) emptyList() else selected.filter { it in friendIds }
}
