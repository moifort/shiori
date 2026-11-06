package com.polyforms.shiori.features.authors

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.polyforms.shiori.shared.CursorPage
import com.polyforms.shiori.shared.SnapshotCache
import com.polyforms.shiori.shared.isCancellation
import com.polyforms.shiori.shared.reportError
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.serialization.KSerializer
import kotlinx.serialization.builtins.ListSerializer

/** The Authors or Narrators shelf: paged by recency or love, whole when alphabetical. */
class PersonListViewModel<Person : ShelvedPerson>(
    private val cacheName: String,
    private val serializer: KSerializer<Person>,
    private val scope: CoroutineScope,
    private val caching: Boolean = true,
    private val list: suspend (limit: Int, after: String?, order: AuthorListOrder) -> CursorPage<Person>,
) {
    var order by mutableStateOf(AuthorListOrder.RECENT)
        private set
    var people by mutableStateOf<List<Person>>(emptyList())
        private set
    var isLoading by mutableStateOf(false)
        private set
    var errorMessage by mutableStateOf<String?>(null)
        private set
    var hasMore by mutableStateOf(false)
        private set
    var loadMoreFailed by mutableStateOf(false)
        private set
    private var isLoadingMore = false
    private var loaded = false
    private var nextCursor: String? = null
    private var generation = 0

    private val pageSize = 40
    private val maxPageSize = 200
    private val prefetchThreshold = 6

    private val cache: SnapshotCache<List<Person>>?
        get() {
            if (!caching) return null
            val suffix = when (order) {
                AuthorListOrder.NAME -> "by-name"
                AuthorListOrder.RECENT -> "by-activity"
                AuthorListOrder.LOVED -> "all"
            }
            return SnapshotCache("$cacheName-$suffix", 8, ListSerializer(serializer))
        }

    init {
        people = cache?.read() ?: emptyList()
    }

    suspend fun show(order: AuthorListOrder) {
        if (order == this.order) return
        this.order = order
        generation += 1
        people = cache?.read() ?: emptyList()
        hasMore = false
        nextCursor = null
        loaded = false
        isLoading = false
        errorMessage = null
        loadOnAppear()
    }

    suspend fun load(keepingDepth: Boolean = false) {
        generation += 1
        val requested = generation
        val wanted = when {
            order == AuthorListOrder.NAME -> Int.MAX_VALUE
            keepingDepth -> maxOf(people.size, pageSize)
            else -> pageSize
        }
        isLoading = true
        errorMessage = null
        isLoadingMore = false
        loadMoreFailed = false
        try {
            val fetched = mutableListOf<Person>()
            var more = true
            var cursor: String? = null
            while (more && fetched.size < wanted) {
                val page = list(minOf(wanted - fetched.size, maxPageSize), cursor, order)
                if (requested != generation) return
                fetched += page.items
                cursor = page.endCursor ?: cursor
                more = page.hasMore && page.items.isNotEmpty()
            }
            people = fetched
            hasMore = more
            nextCursor = cursor
            loaded = true
            cache?.let { cache ->
                val snapshot = if (order == AuthorListOrder.NAME) fetched.toList() else fetched.take(pageSize)
                scope.launch(Dispatchers.IO) { cache.write(snapshot) }
            }
        } catch (error: Exception) {
            if (requested != generation) return
            if (!isCancellation(error)) errorMessage = reportError(error)
        } finally {
            if (requested == generation) isLoading = false
        }
    }

    suspend fun loadMore() {
        if (!hasMore || isLoadingMore) return
        val requested = generation
        isLoadingMore = true
        loadMoreFailed = false
        try {
            val page = list(pageSize, nextCursor, order)
            if (requested != generation) return
            people = people + page.items
            nextCursor = page.endCursor ?: nextCursor
            hasMore = page.hasMore
        } catch (error: Exception) {
            if (isCancellation(error) || requested != generation) return
            loadMoreFailed = true
            errorMessage = reportError(error)
        } finally {
            isLoadingMore = false
        }
    }

    fun prefetchIfNeeded(id: String) {
        if (!hasMore || isLoadingMore) return
        val index = people.indexOfFirst { it.id == id }
        if (index >= 0 && people.size - index <= prefetchThreshold) scope.launch { loadMore() }
    }

    suspend fun loadOnAppear() {
        if (loaded || isLoading) return
        load()
    }
}
