package com.polyforms.shiori.features.search

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.ReadingStatus
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** The search tab: what is typed, the filter, the results, the recents. */
class LibrarySearchViewModel(
    private val index: LibrarySearchIndex,
    private val client: LibrarySearchClient,
    private val scope: CoroutineScope,
    private val recents: RecentSearches = RecentSearches(),
    private val viewed: RecentlyViewed = RecentlyViewed(),
    private val coverDelayMillis: Long = 300,
) {
    var query by mutableStateOf("")
        private set
    var filter by mutableStateOf(SearchFilter())
        private set
    var results by mutableStateOf(SearchResults.empty)
        private set
    var recentSearches by mutableStateOf(recents.all)
        private set
    var recentlyViewed by mutableStateOf<List<Book>>(emptyList())
        private set
    var covers by mutableStateOf<Map<String, String>>(emptyMap())
        private set
    private val asked = mutableSetOf<String>()
    private var coverJob: Job? = null

    val isPreparing: Boolean get() = !index.isReady && !index.failed
    val failed: Boolean get() = !index.isReady && index.failed
    val isSearching: Boolean get() = SearchText.normalized(query).isNotEmpty() || filter.isActive

    fun type(text: String) {
        if (text == query) return
        query = text
        recompute()
    }

    suspend fun appear() {
        index.loadFromDisk()
        recompute()
        index.refreshIfNeeded()
        recompute()
    }

    suspend fun retry() {
        index.refreshIfNeeded()
        recompute()
    }

    fun toggleFavorites() = applyFilter(filter.copy(favorites = !filter.favorites))
    fun select(status: ReadingStatus) = applyFilter(filter.copy(status = if (filter.status == status) null else status))
    fun clearFilter() = applyFilter(SearchFilter())
    fun useRecent(recent: String) = type(recent)

    fun clearRecentSearches() {
        recents.clear()
        recentSearches = emptyList()
    }

    fun refreshViewed() = recompute()

    fun opened() {
        recents.remember(query)
        recentSearches = recents.all
    }

    private fun applyFilter(value: SearchFilter) {
        if (value == filter) return
        filter = value
        recompute()
    }

    private fun recompute() {
        results = LibrarySearchMatcher.results(query, index.entries, filter)
        val byId = index.entries.associateBy({ it.id }, { it.book })
        recentlyViewed = viewed.ids.mapNotNull { byId[it] }
        scheduleCovers()
    }

    private fun scheduleCovers() {
        coverJob?.cancel()
        val shown = recentlyViewed + results.series.mapNotNull { it.books.firstOrNull() } + results.books
        val missing = shown.map { it.id }.filter { it !in asked }.distinct().take(COVER_BATCH)
        if (missing.isEmpty()) return
        coverJob = scope.launch {
            delay(coverDelayMillis)
            asked += missing
            try {
                covers = covers + client.covers(missing)
            } catch (error: Exception) {
                asked -= missing.toSet()
            }
        }
    }

    companion object {
        const val COVER_BATCH = 50
    }
}
