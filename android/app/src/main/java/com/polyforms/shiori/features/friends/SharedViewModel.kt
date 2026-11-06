package com.polyforms.shiori.features.friends

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.polyforms.shiori.shared.SnapshotCache
import com.polyforms.shiori.shared.isCancellation
import com.polyforms.shiori.shared.reportError
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import java.text.Collator

/**
 * Owns the Partagé screen: the reader's own shelf as their friends see it, the friends, and the
 * one in-flight load. It opens on what it last showed, kept on disk, brought up to date silently.
 */
class SharedViewModel(private val client: FriendsClient, private val scope: CoroutineScope, caching: Boolean = true) {
    @Serializable
    private data class Snapshot(val friends: List<Friend>, val myShelf: FriendProfile?)

    private val cache = if (caching) SnapshotCache("shared", 5, Snapshot.serializer()) else null

    var friends by mutableStateOf<List<Friend>>(emptyList())
        private set
    var myShelf by mutableStateOf<FriendProfile?>(null)
        private set
    var isLoading by mutableStateOf(false)
        private set

    /** The friends list could not be read. Only drawn when there is nothing else on screen. */
    var loadFailed by mutableStateOf<String?>(null)
        private set

    /** The server has answered at least once, so the rows are no longer the snapshot. */
    var loaded by mutableStateOf(false)
        private set

    /** The invitation just created, shown as a sheet the moment it comes back. */
    var invitation by mutableStateOf<FriendInvitation?>(null)
    var isInviting by mutableStateOf(false)
        private set

    /** The first name of the friend an invitation just joined. */
    var accepted by mutableStateOf<String?>(null)

    /** A write that failed, said in an alert. */
    var errorMessage by mutableStateOf<String?>(null)

    init {
        cache?.read()?.let {
            friends = it.friends
            myShelf = it.myShelf
        }
    }

    val isEmpty: Boolean get() = friends.isEmpty() && myShelf == null

    /** A refresh that fails over rows already on screen says nothing: a pull tries again. */
    suspend fun load() {
        if (isLoading) return
        isLoading = true
        var failed = false
        coroutineScope {
            // The two reads are independent: one failing leaves the other.
            val shelf = async { runCatching { client.myShelf() } }
            try {
                friends = client.friends()
                loadFailed = null
                loaded = true
            } catch (error: Throwable) {
                if (!isCancellation(error)) {
                    loadFailed = reportError(error)
                    failed = true
                }
            }
            shelf.await()
                .onSuccess {
                    myShelf = it
                    loaded = true
                }
                .onFailure {
                    if (!isCancellation(it)) {
                        reportError(it)
                        failed = true
                    }
                }
        }
        isLoading = false
        if (!failed) write()
    }

    /** A screen never loaded loads; one the server already answered asks nothing. */
    suspend fun loadOnAppear() {
        if (!loaded && !isLoading) load()
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

    /** Takes an invitation up from the code or the link the reader pasted. */
    suspend fun accept(code: String) {
        val trimmed = code.trim()
        if (trimmed.isEmpty()) return
        val parsed = runCatching { android.net.Uri.parse(trimmed) }.getOrNull()?.let(InvitationLink::code) ?: trimmed.uppercase()
        try {
            val friend = client.accept(parsed)
            accepted = friend.displayName
            add(friend)
        } catch (error: Throwable) {
            if (!isCancellation(error)) errorMessage = reportError(error)
        }
    }

    /** Stops sharing with a friend, both ways. */
    suspend fun remove(friend: Friend) {
        try {
            client.remove(friend.userId)
            friends = friends.filter { it.userId != friend.userId }
            write()
        } catch (error: Throwable) {
            if (!isCancellation(error)) errorMessage = reportError(error)
        }
    }

    /** A friend the reader just accepted, filed by first name as the server files them. */
    private fun add(friend: Friend) {
        val collator = Collator.getInstance()
        friends = (friends.filter { it.userId != friend.userId } + friend).sortedWith { a, b -> collator.compare(a.firstName ?: "", b.firstName ?: "") }
        write()
    }

    private fun write() {
        val cache = cache ?: return
        val snapshot = Snapshot(friends, myShelf)
        scope.launch(Dispatchers.IO) { cache.write(snapshot) }
    }
}
