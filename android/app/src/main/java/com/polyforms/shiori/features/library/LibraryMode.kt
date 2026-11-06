package com.polyforms.shiori.features.library

import com.polyforms.shiori.shared.L

/** The Library's orders: every book by date, or the loved first. */
enum class LibraryMode {
    ALL, FAVORITES;

    val label: String get() = if (this == ALL) L("Tout") else L("Favoris")
    val icon: String get() = if (this == ALL) "clock" else "heart.fill"
    val subtitle: String get() = if (this == ALL) L("Par date") else L("Cœurs, puis étoiles")

    companion object {
        val seriesViews = listOf(ALL, FAVORITES)
    }
}
