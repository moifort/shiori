package com.polyforms.shiori.features.search

import android.content.Context
import com.polyforms.shiori.shared.AppContext

/** The last books opened, newest first, ten at most: the search page's "Consultés récemment". */
class RecentlyViewed(private val key: String = "recently-viewed-books") {
    private val prefs get() = AppContext.get().getSharedPreferences("shiori", Context.MODE_PRIVATE)

    val ids: List<String> get() = prefs.getString(key, null)?.split("\n")?.filter { it.isNotEmpty() }.orEmpty()

    fun remember(id: String) {
        prefs.edit().putString(key, (listOf(id) + ids.filter { it != id }).take(LIMIT).joinToString("\n")).apply()
    }

    fun clear() {
        prefs.edit().remove(key).apply()
    }

    companion object {
        const val LIMIT = 10
    }
}
