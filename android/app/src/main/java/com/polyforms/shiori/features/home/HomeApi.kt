package com.polyforms.shiori.features.home

import com.polyforms.shiori.graphql.DashboardQuery
import com.polyforms.shiori.graphql.GenreInsightsQuery
import com.polyforms.shiori.graphql.fragment.DashboardBookCard
import com.polyforms.shiori.graphql.fragment.TastePlace
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.GraphQLClient
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.SeriesMembership
import com.polyforms.shiori.shared.Showcase
import com.polyforms.shiori.shared.asDomain
import com.polyforms.shiori.shared.parseISO8601
import java.time.ZoneId
import kotlin.math.roundToInt

object HomeApi {
    suspend fun dashboard(): Dashboard {
        if (Showcase.isOn) return HomeFixtures.dashboard
        val d = GraphQLClient.fetch(DashboardQuery(ZoneId.systemDefault().id)).dashboard.dashboardFields
        return Dashboard(
            currentYear = d.currentYear,
            booksPerYear = d.booksPerYear.map { Dashboard.YearCount(it.year, it.count) },
            pagesPerMonth = d.pagesPerMonth.map { Dashboard.MonthPages(it.month, it.pages) },
            hoursPerMonth = d.hoursPerMonth.map { Dashboard.MonthHours(it.month, it.hours) },
            reading = d.reading.map { it.dashboardBookCard.asBook(ReadingStatus.READING) },
            toRead = d.toRead.map { it.dashboardBookCard.asBook(ReadingStatus.TO_READ) },
            lastFinished = d.lastFinished?.dashboardBookCard?.asBook(ReadingStatus.READ),
            toReadCount = d.toReadCount,
            readCount = d.readCount,
            pagesRead = d.pagesRead,
            hoursListened = d.hoursListened,
            genres = d.genres.map { Dashboard.GenreSlice(it.genre?.asDomain, it.count) },
            series = d.series.map {
                Dashboard.SeriesProgress(
                    id = it.id,
                    name = it.name,
                    isAudio = it.audio,
                    language = it.language?.asDomain,
                    readCount = it.readCount,
                    totalCount = it.totalCount,
                    rating = it.rating?.let { r -> (r * 2).roundToInt() / 2.0 },
                    favorite = it.favorite,
                    coverURL = it.coverUrl,
                )
            },
            favoriteCount = d.favoriteCount,
            hasAudiobooks = d.hasAudiobooks,
            hasPrintedBooks = d.hasPrintedBooks,
            libraryIsEmpty = d.libraryIsEmpty,
        )
    }

    suspend fun genreInsights(): GenreInsights {
        if (Showcase.isOn) return HomeFixtures.genreInsights
        val i = GraphQLClient.fetch(GenreInsightsQuery()).genreInsights
        return GenreInsights(
            readCount = i.readCount,
            shares = i.shares.map { GenreInsights.Share(it.genre.asDomain, it.count) },
            formats = i.formats.map { GenreInsights.FormatShare(it.format.asDomain, it.count, it.topGenre?.asDomain) },
            tastes = i.tasteMap.map { it.tastePlace.asTaste },
            averageRating = i.averageRating,
            gem = i.gem?.tastePlace?.asTaste,
            longest = i.longest?.let { GenreInsights.LongestRecord(it.genre.asDomain, it.averagePages) },
            fastest = i.fastest?.let { GenreInsights.FastestRecord(it.genre.asDomain, it.averageDays) },
            mostDropped = i.mostDropped?.let { GenreInsights.DroppedRecord(it.genre.asDomain, it.droppedCount, it.startedCount) },
            unexplored = i.unexplored.map { GenreInsights.Unexplored(it.genre.asDomain, it.pileCount) },
        )
    }
}

private val TastePlace.asTaste: GenreInsights.Taste get() = GenreInsights.Taste(genre.asDomain, subgenre, readCount, averageRating)

private fun DashboardBookCard.asBook(status: ReadingStatus) = Book(
    id = id,
    title = title,
    authors = authors,
    format = format.asDomain,
    pageCount = pageCount,
    currentPage = currentPage,
    durationMinutes = durationMinutes,
    listeningProgress = listeningProgress?.toInt(),
    series = series?.let { SeriesMembership(it.id, it.name, it.volume, it.kind.asDomain) },
    coverURL = coverUrl,
    status = status,
    rating = rating,
    addedAt = parseISO8601(addedAt),
    startedAt = parseISO8601(startedAt),
    finishedAt = parseISO8601(finishedAt),
)

/** The home's previews and the showcase. */
object HomeFixtures {
    val dashboard = Dashboard(
        currentYear = 2026,
        booksPerYear = listOf(Dashboard.YearCount(2026, 83)),
        pagesPerMonth = listOf(320, 1712, 2032, 320, 1976, 1008, 1104, 2712, 3288, 1792).mapIndexed { i, p -> Dashboard.MonthPages(i + 1, p) },
        hoursPerMonth = emptyList(),
        reading = emptyList(),
        lastFinished = null,
        toReadCount = 18,
        readCount = 83,
        genres = emptyList(),
        series = emptyList(),
        favoriteCount = 15,
        libraryIsEmpty = false,
    )

    val genreInsights = GenreInsights(0, emptyList(), emptyList(), emptyList(), null, null, null, null, null, emptyList())
}

/** "Il y a N jours", counted in calendar days. */
fun java.time.Instant.daysAgo(now: java.time.Instant = java.time.Instant.now()): Int {
    val zone = ZoneId.systemDefault()
    return maxOf(0, java.time.temporal.ChronoUnit.DAYS.between(atZone(zone).toLocalDate(), now.atZone(zone).toLocalDate()).toInt())
}
