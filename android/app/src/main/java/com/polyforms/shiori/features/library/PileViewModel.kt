package com.polyforms.shiori.features.library

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.polyforms.shiori.features.wishlist.Wishlist
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookGenre
import com.polyforms.shiori.shared.SnapshotCache
import com.polyforms.shiori.shared.isCancellation
import com.polyforms.shiori.shared.reportError
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch

/** The pile to read, cut into what to finish, what is recommended, what is awarded… */
class PileViewModel(private val client: LibraryClient, private val scope: CoroutineScope, view: ShelvesView = ShelvesView(), private val caching: Boolean = true) {
    private val openedGenre = view.genre
    private val wishlistCache = if (caching) Wishlist.cache else null

    var view by mutableStateOf(view)
        private set
    var pile by mutableStateOf(cache(view)?.read() ?: Pile())
        private set
    var wishlist by mutableStateOf(wishlistCache?.read() ?: Wishlist())
        private set
    var isLoading by mutableStateOf(false)
        private set
    var errorMessage by mutableStateOf<String?>(null)
        private set
    var genres by mutableStateOf(pile.genres)
        private set
    private var loaded = false
    private var generation = 0

    val shownGenres: List<BookGenre> get() = if (openedGenre == null && genres.size > 1) genres else emptyList()
    val wished: List<Book> get() = wishlist.availableNow.filter { view.format == null || it.format == view.format }

    private fun cache(view: ShelvesView) = if (caching) SnapshotCache("pile-${view.cacheKey}", 2, Pile.serializer()) else null

    suspend fun select(genre: BookGenre?) {
        if (view.genre == genre) return
        view = view.copy(genre = genre)
        cache(view)?.read()?.let { pile = it }
        load()
    }

    suspend fun loadOnAppear() {
        if (loaded || isLoading) return
        load()
    }

    suspend fun load() {
        generation += 1
        val requested = generation
        val asked = view
        isLoading = true
        errorMessage = null
        try {
            coroutineScope {
                val wishes = async { runCatching { client.wishlist() }.getOrNull() }
                val fetched = client.pile(asked)
                val wished = wishes.await()
                if (requested != generation) return@coroutineScope
                if (wished != null) {
                    wishlist = wished
                    wishlistCache?.let { cache -> scope.launch(Dispatchers.IO) { cache.write(wished) } }
                }
                pile = fetched
                if (asked.genre == openedGenre || genres.isEmpty()) genres = fetched.genres
                loaded = true
                cache(asked)?.let { cache -> scope.launch(Dispatchers.IO) { cache.write(fetched) } }
            }
        } catch (error: Exception) {
            if (requested == generation && !isCancellation(error)) errorMessage = reportError(error)
        } finally {
            if (requested == generation) isLoading = false
        }
    }
}
