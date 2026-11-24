package com.polyforms.shiori.features.home

import com.polyforms.shiori.features.discover.MonthlyDiscoveries
import com.polyforms.shiori.features.discover.asDomain
import com.polyforms.shiori.graphql.DashboardQuery
import com.polyforms.shiori.graphql.DismissHomePromptMutation
import com.polyforms.shiori.graphql.HomeOpeningQuery
import com.polyforms.shiori.graphql.fragment.DashboardFields
import com.polyforms.shiori.graphql.fragment.MonthlyDiscoveriesFields
import com.polyforms.shiori.graphql.type.DiscoveriesStatus
import com.polyforms.shiori.graphql.type.HomePrompt as GHomePrompt
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
        if (Showcase.isOn) return com.polyforms.shiori.DebugFixtures.dashboard
        return GraphQLClient.fetch(DashboardQuery(ZoneId.systemDefault().id)).dashboard.dashboardFields.asDashboard
    }

    /**
     * The dashboard, the month's discoveries and the hero's prompts in one request: the server
     * reads the library once for all of them.
     */
    suspend fun opening(): HomeOpening {
        if (Showcase.isOn) return HomeOpening(com.polyforms.shiori.DebugFixtures.dashboard, com.polyforms.shiori.DebugFixtures.discoveries, HomeFixtures.prompts)
        val data = GraphQLClient.fetch(HomeOpeningQuery(ZoneId.systemDefault().id))
        return HomeOpening(
            dashboard = data.dashboard.dashboardFields.asDashboard,
            discoveries = data.monthlyDiscoveries.monthlyDiscoveriesFields.asDiscoveries,
            // A prompt a newer server names and this build does not know is left out.
            prompts = data.me.homePrompts.mapNotNull { prompt -> HomePrompt.entries.firstOrNull { it.name == prompt.rawValue } },
        )
    }

    /** A prompt turned down, or taken back: kept on the account, so it holds on every device. */
    suspend fun dismiss(prompt: HomePrompt, dismissed: Boolean) {
        val value = when (prompt) {
            HomePrompt.AUDIBLE -> GHomePrompt.AUDIBLE
            HomePrompt.KINDLE -> GHomePrompt.KINDLE
            HomePrompt.FRIENDS -> GHomePrompt.FRIENDS
        }
        GraphQLClient.perform(DismissHomePromptMutation(value, dismissed), changesLibrary = false)
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

private val DashboardFields.asDashboard: Dashboard
    get() = Dashboard(
        currentYear = currentYear,
        booksPerYear = booksPerYear.map { Dashboard.YearCount(it.year, it.count) },
        pagesPerMonth = pagesPerMonth.map { Dashboard.MonthPages(it.month, it.pages) },
        hoursPerMonth = hoursPerMonth.map { Dashboard.MonthHours(it.month, it.hours) },
        reading = reading.map { it.dashboardBookCard.asBook(ReadingStatus.READING) },
        toRead = toRead.map { it.dashboardBookCard.asBook(ReadingStatus.TO_READ) },
        lastFinished = lastFinished?.dashboardBookCard?.asBook(ReadingStatus.READ),
        toReadCount = toReadCount,
        readCount = readCount,
        pagesRead = pagesRead,
        hoursListened = hoursListened,
        genres = genres.map { Dashboard.GenreSlice(it.genre?.asDomain, it.count) },
        series = series.map {
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
        favoriteCount = favoriteCount,
        hasAudiobooks = hasAudiobooks,
        hasPrintedBooks = hasPrintedBooks,
        libraryIsEmpty = libraryIsEmpty,
    )

private val MonthlyDiscoveriesFields.asDiscoveries: MonthlyDiscoveries
    get() = MonthlyDiscoveries(
        month = month,
        status = when (status) {
            DiscoveriesStatus.READY -> MonthlyDiscoveries.Status.READY
            DiscoveriesStatus.SEARCHING -> MonthlyDiscoveries.Status.SEARCHING
            else -> MonthlyDiscoveries.Status.NONE
        },
        suggestions = suggestions.map { it.suggestionFields.asDomain },
        needsRatings = needsRatings,
    )

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
    audibleAsin = audibleAsin,
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

    val prompts = listOf(HomePrompt.AUDIBLE, HomePrompt.KINDLE, HomePrompt.FRIENDS)

    /** An Audible audiobook under way, as the player draws its button. */
    val listenButton = com.polyforms.shiori.features.listening.ListeningButtonState.RESUME

    /** A library with nothing on it yet: the empty hero and the sources to connect. */
    val emptyDashboard = Dashboard(
        currentYear = 2026,
        booksPerYear = emptyList(),
        pagesPerMonth = emptyList(),
        hoursPerMonth = emptyList(),
        reading = emptyList(),
        lastFinished = null,
        toReadCount = 0,
        genres = emptyList(),
        series = emptyList(),
        libraryIsEmpty = true,
    )

    val genreInsights = GenreInsights(0, emptyList(), emptyList(), emptyList(), null, null, null, null, null, emptyList())
}

/** "Il y a N jours", counted in calendar days. */
fun java.time.Instant.daysAgo(now: java.time.Instant = java.time.Instant.now()): Int {
    val zone = ZoneId.systemDefault()
    return maxOf(0, java.time.temporal.ChronoUnit.DAYS.between(atZone(zone).toLocalDate(), now.atZone(zone).toLocalDate()).toInt())
}
