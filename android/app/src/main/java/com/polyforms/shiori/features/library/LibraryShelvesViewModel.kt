package com.polyforms.shiori.features.library

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookGenre
import com.polyforms.shiori.shared.SnapshotCache
import com.polyforms.shiori.shared.isCancellation
import com.polyforms.shiori.shared.reportError
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/** The Library's first page, or a genre's: the rails and the pills that narrow them. */
class LibraryShelvesViewModel(
    private val client: LibraryClient,
    private val scope: CoroutineScope,
    genre: BookGenre? = null,
    private val caching: Boolean = true,
) {
    var view by mutableStateOf(ShelvesView(genre = genre))
        private set
    var shelves by mutableStateOf(LibraryShelves())
        private set
    var isLoading by mutableStateOf(false)
        private set
    var errorMessage by mutableStateOf<String?>(null)
        private set
    var formats by mutableStateOf<List<BookFormat>>(emptyList())
        private set
    var subgenres by mutableStateOf<List<String>>(emptyList())
        private set
    private var loaded = false
    private var generation = 0

    init {
        cache(view)?.read()?.let {
            shelves = it
            formats = it.formats
            subgenres = it.subgenres
        }
    }

    private fun cache(view: ShelvesView) =
        if (caching) SnapshotCache("library-shelves-${view.cacheKey}", 1, LibraryShelves.serializer()) else null

    suspend fun select(format: BookFormat?) {
        if (view.format == format) return
        view = view.copy(format = format)
        switchView()
    }

    suspend fun select(subgenre: String?) {
        if (view.subgenre == subgenre) return
        view = view.copy(subgenre = subgenre)
        switchView()
    }

    private suspend fun switchView() {
        cache(view)?.read()?.let { shelves = it }
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
            val fetched = client.shelves(asked)
            if (requested != generation) return
            shelves = fetched
            if (asked.format == null || formats.isEmpty()) formats = fetched.formats
            if (asked.subgenre == null || subgenres.isEmpty()) subgenres = fetched.subgenres
            loaded = true
            cache(asked)?.let { cache -> scope.launch(Dispatchers.IO) { cache.write(fetched) } }
        } catch (error: Exception) {
            if (requested != generation) return
            if (!isCancellation(error)) errorMessage = reportError(error)
        } finally {
            if (requested == generation) isLoading = false
        }
    }
}
