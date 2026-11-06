package com.polyforms.shiori.features.home

import android.content.Context
import com.polyforms.shiori.features.discover.AwaitedEdition
import com.polyforms.shiori.features.discover.DiscoveryVolume
import com.polyforms.shiori.shared.AppContext
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.SeriesMembership
import com.polyforms.shiori.shared.VolumeKind
import kotlinx.serialization.Serializable

/** Something out or coming the Home shows: a saga's volume, or an awaited edition. */
@Serializable
sealed interface HomeRelease {
    val id: String
    val date: String?
    val name: String

    @Serializable
    data class Volume(val release: DiscoveryVolume) : HomeRelease {
        override val id: String get() = release.id
        override val date: String? get() = release.volume.date
        override val name: String get() = release.saga.series.name
    }

    @Serializable
    data class Awaited(val edition: AwaitedEdition) : HomeRelease {
        override val id: String get() = "awaited-${edition.id}"
        override val date: String? get() = edition.date
        override val name: String get() = edition.title
    }
}

/** A release as a cover draws it. */
fun releaseTile(release: HomeRelease): Book = when (release) {
    is HomeRelease.Awaited -> release.edition.cover
    is HomeRelease.Volume -> {
        val series = release.release.saga.series
        val volume = release.release.volume
        Book(
            id = "release-${series.id}-${volume.number}",
            title = volume.title,
            authors = listOfNotNull(series.author),
            format = if (series.isAudio) BookFormat.AUDIOBOOK else BookFormat.BOOK,
            genre = series.genre,
            language = series.language,
            series = SeriesMembership(series.seriesId, series.name, volume.number, VolumeKind.MAIN),
            coverURL = volume.coverURL,
            status = ReadingStatus.TO_READ,
        )
    }
}

/** The releases the reader marked seen on the Home, kept on the device, the latest two hundred. */
class SeenReleases(private val key: String = "home-seen-releases") {
    private val preferences get() = AppContext.get().getSharedPreferences("shiori", Context.MODE_PRIVATE)
    private fun read(): List<String> = preferences.getString(key, null)?.split("\n")?.filter { it.isNotEmpty() } ?: emptyList()
    private fun write(ids: List<String>) = preferences.edit().putString(key, ids.joinToString("\n")).apply()

    val all: Set<String> get() = read().toSet()

    fun see(id: String) = write((read().filter { it != id } + id).takeLast(LIMIT))

    fun unsee(id: String) = write(read().filter { it != id })

    companion object {
        const val LIMIT = 200
    }
}
