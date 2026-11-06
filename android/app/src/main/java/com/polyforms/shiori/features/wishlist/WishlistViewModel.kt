package com.polyforms.shiori.features.wishlist

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.polyforms.shiori.features.book.BookAddition
import com.polyforms.shiori.features.book.BookDraft
import com.polyforms.shiori.features.discover.AwaitedApi
import com.polyforms.shiori.shared.AnalyticsEvent
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.isCancellation
import com.polyforms.shiori.shared.reportError
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/** What the wishlist asks of the server. */
interface WishlistClient {
    suspend fun wishlist(): Wishlist
    suspend fun remove(wishId: String)
    suspend fun addBook(draft: BookDraft)
    suspend fun stopAwaiting(editionId: String)

    companion object {
        val live: WishlistClient = object : WishlistClient {
            override suspend fun wishlist() = WishlistApi.wishlist()
            override suspend fun remove(wishId: String) = WishlistApi.remove(wishId)
            override suspend fun addBook(draft: BookDraft) {
                BookAddition.add(draft, source = AnalyticsEvent.BookSource.MANUAL)
            }
            override suspend fun stopAwaiting(editionId: String) = AwaitedApi.stop(editionId)
        }
    }
}

/** The wishlist: the editions awaited and the books wished, narrowed to a format. */
class WishlistViewModel(private val client: WishlistClient, private val scope: CoroutineScope, caching: Boolean = true) {
    private val cache = if (caching) Wishlist.cache else null

    var wishlist by mutableStateOf(cache?.read() ?: Wishlist())
        private set
    var isLoading by mutableStateOf(false)
        private set
    var errorMessage by mutableStateOf<String?>(null)
        private set
    var actionError by mutableStateOf<String?>(null)
    var format by mutableStateOf<BookFormat?>(null)
    private var loaded = false

    val formats: List<BookFormat>
        get() {
            val held = (wishlist.wishes.map { it.format } + wishlist.awaited.map { it.cover.format }).toSet()
            return BookFormat.entries.filter { it in held }
        }

    val shown: Wishlist
        get() {
            val format = format ?: return wishlist
            return Wishlist(wishlist.wishes.filter { it.format == format }, wishlist.awaited.filter { it.cover.format == format })
        }

    suspend fun loadOnAppear() {
        if (loaded || isLoading) return
        load()
    }

    suspend fun load() {
        isLoading = true
        errorMessage = null
        try {
            val fetched = client.wishlist()
            wishlist = fetched
            loaded = true
            if (format != null && format !in formats) format = null
            cache?.let { cache -> scope.launch(Dispatchers.IO) { cache.write(fetched) } }
        } catch (error: Exception) {
            if (!isCancellation(error)) errorMessage = reportError(error)
        } finally {
            isLoading = false
        }
    }

    suspend fun add(wish: Wish, status: ReadingStatus) = act(wish) { client.addBook(wish.draft(status)) }

    suspend fun remove(wish: Wish) = act(wish) { client.remove(wish.id) }

    private suspend fun act(wish: Wish, work: suspend () -> Unit) {
        try {
            work()
            wishlist = wishlist.copy(wishes = wishlist.wishes.filter { it.id != wish.id })
        } catch (error: Exception) {
            if (!isCancellation(error)) actionError = reportError(error)
        }
    }
}
