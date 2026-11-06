package com.polyforms.shiori.features.home

import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookGenre
import com.polyforms.shiori.shared.BookLanguage
import kotlinx.serialization.Serializable

/** The home dashboard: the year's figures and charts, the books under way, the sagas. */
@Serializable
data class Dashboard(
    val currentYear: Int,
    val booksPerYear: List<YearCount>,
    val pagesPerMonth: List<MonthPages>,
    val hoursPerMonth: List<MonthHours>,
    val reading: List<Book>,
    val toRead: List<Book> = emptyList(),
    val lastFinished: Book?,
    val toReadCount: Int,
    val readCount: Int = 0,
    val pagesRead: Int = 0,
    val hoursListened: Int = 0,
    val genres: List<GenreSlice>,
    val series: List<SeriesProgress>,
    val favoriteCount: Int = 0,
    val hasAudiobooks: Boolean = false,
    val hasPrintedBooks: Boolean = true,
    val libraryIsEmpty: Boolean,
) {
    @Serializable data class YearCount(val year: Int, val count: Int)
    @Serializable data class MonthPages(val month: Int, val pages: Int)
    @Serializable data class MonthHours(val month: Int, val hours: Int)

    @Serializable
    data class GenreSlice(val genre: BookGenre?, val count: Int) {
        val id: String get() = genre?.name ?: "others"
    }

    @Serializable
    data class SeriesProgress(
        val id: String,
        val name: String,
        val isAudio: Boolean = false,
        val language: BookLanguage? = null,
        val readCount: Int,
        val totalCount: Int,
        val rating: Double? = null,
        val favorite: Boolean = false,
        val coverURL: String? = null,
    )

    val readThisYear: Int get() = booksPerYear.firstOrNull { it.year == currentYear }?.count ?: 0
    val pagesThisYear: Int get() = pagesPerMonth.sumOf { it.pages }
    val hoursThisYear: Int get() = hoursPerMonth.sumOf { it.hours }
}

/** What the reader's genres say of them: shares, tastes, records, the unexplored. */
@Serializable
data class GenreInsights(
    val readCount: Int,
    val shares: List<Share>,
    val formats: List<FormatShare>,
    val tastes: List<Taste>,
    val averageRating: Double?,
    val gem: Taste?,
    val longest: LongestRecord?,
    val fastest: FastestRecord?,
    val mostDropped: DroppedRecord?,
    val unexplored: List<Unexplored>,
) {
    @Serializable data class Share(val genre: BookGenre, val count: Int)
    @Serializable data class FormatShare(val format: BookFormat, val count: Int, val topGenre: BookGenre?)

    @Serializable
    data class Taste(val genre: BookGenre, val subgenre: String? = null, val readCount: Int, val averageRating: Double) {
        val id: String get() = "${genre.name}~${subgenre ?: ""}"
        val label: String get() = subgenre ?: genre.label
    }

    @Serializable data class LongestRecord(val genre: BookGenre, val averagePages: Int)
    @Serializable data class FastestRecord(val genre: BookGenre, val averageDays: Int)
    @Serializable data class DroppedRecord(val genre: BookGenre, val droppedCount: Int, val startedCount: Int)
    @Serializable data class Unexplored(val genre: BookGenre, val pileCount: Int)
}
