package com.polyforms.shiori.features.friends

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.polyforms.shiori.shared.isCancellation
import com.polyforms.shiori.shared.reportError

/**
 * A friend's paged shelf — their books or their sagas — with the long press that takes a row onto
 * the reader's own. The query the rows were asked under is kept: until the answer for a new one
 * arrives, the rows of the last would be cut the new way, so the page shows a spinner instead.
 */
class FriendShelfListModel<Row>(private val idOf: (Row) -> String, private val owning: (Row) -> Row) {
    var rows by mutableStateOf<List<Row>>(emptyList())
        private set
    var hasMore by mutableStateOf(false)
        private set

    /** The query the rows on screen answer; null before the first answer. */
    var loadedQuery by mutableStateOf<String?>(null)
        private set
    var errorMessage by mutableStateOf<String?>(null)
        private set
    var loadMoreFailed by mutableStateOf(false)
        private set

    /** The rows being taken onto the reader's shelf. */
    var adding by mutableStateOf<Set<String>>(emptySet())
        private set

    /** A take that failed, said in an alert. */
    var addFailed by mutableStateOf<String?>(null)

    /** The first page of a new query. A cancellation — the reader switched view again — says nothing. */
    suspend fun load(query: String, fetch: suspend (String?) -> Pair<List<Row>, Boolean>) {
        errorMessage = null
        loadMoreFailed = false
        try {
            val (page, more) = fetch(null)
            rows = page
            hasMore = more
            loadedQuery = query
        } catch (error: Throwable) {
            if (!isCancellation(error)) errorMessage = reportError(error)
        }
    }

    /** The next page, appended; a row the server sends twice is kept once. */
    suspend fun loadMore(fetch: suspend (String?) -> Pair<List<Row>, Boolean>) {
        loadMoreFailed = false
        try {
            val (page, more) = fetch(rows.lastOrNull()?.let(idOf))
            val known = rows.map(idOf).toSet()
            rows = rows + page.filter { idOf(it) !in known }
            hasMore = more
        } catch (error: Throwable) {
            if (!isCancellation(error)) {
                reportError(error)
                loadMoreFailed = true
            }
        }
    }

    /** Takes a row onto the reader's shelf; the row then says it is theirs. */
    suspend fun take(rowId: String, add: suspend () -> Unit) {
        adding = adding + rowId
        try {
            add()
            markOwned(rowId)
        } catch (error: Throwable) {
            if (!isCancellation(error)) addFailed = reportError(error)
        }
        adding = adding - rowId
    }

    fun markOwned(rowId: String) {
        rows = rows.map { if (idOf(it) == rowId) owning(it) else it }
    }
}
