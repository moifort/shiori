package com.polyforms.shiori.features.series

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.polyforms.shiori.shared.DiscoveredVolume
import com.polyforms.shiori.shared.FollowedSeries
import com.polyforms.shiori.shared.ReleaseDateText
import com.polyforms.shiori.shared.SnapshotCache
import com.polyforms.shiori.shared.isCancellation
import com.polyforms.shiori.shared.reportError
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.serialization.builtins.ListSerializer

/** The reader's sagas: what to read next, what is announced, and every saga under a filter. */
class SeriesShelfViewModel(
    private val client: SeriesClient,
    private val scope: CoroutineScope,
    filter: SeriesShelfFilter = SeriesShelfFilter.ALL,
    caching: Boolean = true,
) {
    private val cache = if (caching) SnapshotCache("series-shelf", 1, ListSerializer(FollowedSeries.serializer())) else null

    var series by mutableStateOf(cache?.read() ?: emptyList())
        private set
    var isLoading by mutableStateOf(false)
        private set
    var errorMessage by mutableStateOf<String?>(null)
        private set
    var filter by mutableStateOf(filter)
    private var loaded = false

    private val followed: List<FollowedSeries> get() = series.filter { !it.isSetAside }
    val upNext: List<Pair<FollowedSeries, NextVolume>> get() = followed.upNext
    val releases: List<Pair<FollowedSeries, DiscoveredVolume>>
        get() = followed
            .mapNotNull { saga -> saga.announced?.let { saga to it } }
            .filter { (_, volume) -> volume.date?.let { ReleaseDateText.isUpcoming(it) } ?: true }
            .sortedBy { (_, volume) -> volume.date?.let { ReleaseDateText.lastDay(it) } ?: "￿" }
            .take(RELEASE_LIMIT)
    val filters: List<SeriesShelfFilter> get() = SeriesShelfFilter.offered(series)
    val filtered: List<FollowedSeries> get() = series.filter(filter::keeps)
    val setAside: List<FollowedSeries> get() = series.filter { it.isSetAside }

    suspend fun loadOnAppear() {
        if (loaded || isLoading) return
        load()
    }

    suspend fun load() {
        isLoading = true
        errorMessage = null
        try {
            val fetched = mutableListOf<FollowedSeries>()
            var cursor: String? = null
            for (round in 0 until MAX_PAGES) {
                val page = client.page(PAGE_SIZE, cursor)
                fetched += page.items
                cursor = page.endCursor
                if (!page.hasMore || cursor == null) break
            }
            series = fetched
            loaded = true
            if (filter !in filters) filter = SeriesShelfFilter.ALL
            cache?.let { cache -> scope.launch(Dispatchers.IO) { cache.write(fetched.toList()) } }
        } catch (error: Exception) {
            if (!isCancellation(error)) errorMessage = reportError(error)
        } finally {
            isLoading = false
        }
    }

    suspend fun follow(saga: FollowedSeries) {
        try {
            client.setFollowed(saga.seriesId, true)
            load()
        } catch (error: Exception) {
            if (!isCancellation(error)) errorMessage = reportError(error)
        }
    }

    companion object {
        const val RELEASE_LIMIT = 5
        private const val PAGE_SIZE = 200
        private const val MAX_PAGES = 5
    }
}
