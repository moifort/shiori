package com.polyforms.shiori.features.search

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.DataChanges
import com.polyforms.shiori.shared.InstantSerializer
import com.polyforms.shiori.shared.SnapshotCache
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import java.time.Duration
import java.time.Instant

/** What the search reads: the whole library, and covers by book. */
interface LibrarySearchClient {
    suspend fun index(): List<Book>
    suspend fun covers(ids: List<String>): Map<String, String>

    companion object {
        val live: LibrarySearchClient = object : LibrarySearchClient {
            override suspend fun index() = SearchApi.index()
            override suspend fun covers(ids: List<String>) = SearchApi.covers(ids)
        }
    }
}

/** The library kept on the phone for the search: read from disk at once, refreshed hourly. */
class LibrarySearchIndex(private val client: LibrarySearchClient, caching: Boolean = true, private val now: () -> Instant = { Instant.now() }) {
    @Serializable
    data class Stored(val books: List<Book>, @Serializable(InstantSerializer::class) val fetchedAt: Instant)

    var entries by mutableStateOf<List<SearchEntry>>(emptyList())
        private set
    var isReady by mutableStateOf(false)
        private set
    var failed by mutableStateOf(false)
        private set

    private val cache = if (caching) SnapshotCache("library-search", 1, Stored.serializer()) else null
    private var fetchedAt: Instant? = null
    private var stale = false
    private var refreshing: CompletableDeferred<Unit>? = null
    private var generation = 0

    init {
        CoroutineScope(SupervisorJob() + Dispatchers.Main).launch { DataChanges.notices.collect { stale = true } }
    }

    suspend fun loadFromDisk() {
        if (isReady) return
        val stored = withContext(Dispatchers.IO) { cache?.read() } ?: return
        if (!isReady) take(stored.books, stored.fetchedAt)
    }

    suspend fun refreshIfNeeded() {
        val old = fetchedAt?.let { Duration.between(it, now()).seconds > FRESH_FOR_SECONDS } ?: true
        if (isReady && !stale && !old) return
        refreshing?.let { return it.await() }
        val task = CompletableDeferred<Unit>()
        refreshing = task
        try {
            refresh()
        } finally {
            task.complete(Unit)
            refreshing = null
        }
    }

    fun forget() {
        generation += 1
        entries = emptyList()
        isReady = false
        failed = false
        fetchedAt = null
        stale = false
    }

    private suspend fun refresh() {
        stale = false
        val asked = generation
        try {
            val books = client.index()
            if (asked != generation) return
            val fetched = now()
            take(books, fetched)
            failed = false
            withContext(Dispatchers.IO) { cache?.write(Stored(books, fetched)) }
        } catch (error: Exception) {
            if (asked != generation) return
            stale = true
            if (!isReady) failed = true
        }
    }

    private suspend fun take(books: List<Book>, at: Instant) {
        entries = withContext(Dispatchers.Default) { books.map(::SearchEntry) }
        fetchedAt = at
        isReady = true
    }

    companion object {
        private const val FRESH_FOR_SECONDS = 60L * 60
        val shared by lazy { LibrarySearchIndex(LibrarySearchClient.live) }
    }
}
