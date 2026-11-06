package com.polyforms.shiori.features.search

import android.content.Context
import com.polyforms.shiori.graphql.BookCoversQuery
import com.polyforms.shiori.graphql.LibrarySearchIndexQuery
import com.polyforms.shiori.shared.AppContext
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.GraphQLClient
import com.polyforms.shiori.shared.Showcase
import com.polyforms.shiori.shared.asBook

object SearchApi {
    /** Every book of the library, without covers: what the search filters on the phone. */
    suspend fun index(): List<Book> {
        if (Showcase.isOn) return emptyList()
        return GraphQLClient.fetch(LibrarySearchIndexQuery()).librarySearchIndex.map { it.bookSummary.asBook }
    }

    suspend fun covers(ids: List<String>): Map<String, String> {
        if (Showcase.isOn) return emptyMap()
        return GraphQLClient.fetch(BookCoversQuery(ids)).bookCovers.mapNotNull { c -> c.coverUrl?.let { c.id to it } }.toMap()
    }
}

/** The last searches typed, five at most. */
class RecentSearches(private val key: String = "library-search-recents") {
    private val prefs get() = AppContext.get().getSharedPreferences("shiori", Context.MODE_PRIVATE)

    val all: List<String> get() = prefs.getString(key, null)?.split("\n")?.filter { it.isNotEmpty() }.orEmpty()

    fun remember(query: String) {
        val trimmed = query.trim()
        if (SearchText.normalized(trimmed).isEmpty()) return
        val kept = all.filter { SearchText.normalized(it) != SearchText.normalized(trimmed) }
        prefs.edit().putString(key, (listOf(trimmed) + kept).take(LIMIT).joinToString("\n")).apply()
    }

    fun clear() {
        prefs.edit().remove(key).apply()
    }

    companion object {
        const val LIMIT = 5
    }
}
