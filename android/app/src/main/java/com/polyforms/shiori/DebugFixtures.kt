package com.polyforms.shiori

import com.polyforms.shiori.features.discover.AwaitedState
import com.polyforms.shiori.features.discover.MonthlyDiscoveries
import com.polyforms.shiori.features.discover.ReleaseFormat
import com.polyforms.shiori.features.discover.Suggestion
import com.polyforms.shiori.features.home.Dashboard
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookGenre
import com.polyforms.shiori.shared.BookLanguage
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.SeriesMembership
import com.polyforms.shiori.shared.VolumeKind
import java.time.Instant
import java.time.temporal.ChronoUnit

/**
 * Fixtures for the debug previews, their covers read from the app's own files folder, where
 * `adb push` to /data/local/tmp then `run-as … cp` into files/covers puts them.
 */
object DebugFixtures {
    private fun cover(slug: String) = "file:///data/data/com.polyforms.shiori.app/files/covers/$slug.jpg"
    private fun ago(days: Long) = Instant.now().minus(days, ChronoUnit.DAYS)

    private fun book(
        id: String,
        title: String,
        author: String,
        slug: String,
        status: ReadingStatus,
        days: Long = 3,
        series: Pair<String, Int>? = null,
        format: BookFormat = BookFormat.BOOK,
        pageCount: Int? = null,
        currentPage: Int? = null,
        listening: Int? = null,
        genre: BookGenre? = BookGenre.SCIENCE_FICTION,
    ) = Book(
        id = id,
        title = title,
        authors = listOf(author),
        format = format,
        genre = genre,
        pageCount = pageCount,
        currentPage = currentPage,
        durationMinutes = if (format == BookFormat.AUDIOBOOK) 1260 else null,
        listeningProgress = listening,
        language = BookLanguage.FR,
        series = series?.let { SeriesMembership(it.first.lowercase().replace(" ", "-"), it.first, it.second, VolumeKind.MAIN) },
        coverURL = cover(slug),
        status = status,
        startedAt = if (status == ReadingStatus.READING) ago(days) else null,
        addedAt = ago(days),
        shelvedAt = ago(days),
    )

    val reading = listOf(
        book("r1", "Le Nom du vent", "Patrick Rothfuss", "nom-du-vent", ReadingStatus.READING, 12, "Chronique du tueur de roi" to 1, pageCount = 662, currentPage = 214, genre = BookGenre.FANTASY),
        book("r2", "Hypérion", "Dan Simmons", "hyperion-audio-01", ReadingStatus.READING, 4, "Les Cantos d'Hypérion" to 1, BookFormat.AUDIOBOOK, listening = 38),
        book("r3", "Frieren", "Kanehito Yamada", "frieren-05", ReadingStatus.READING, 1, "Frieren" to 5, BookFormat.MANGA, genre = BookGenre.FANTASY),
    )

    val toRead = listOf(
        book("t1", "Fourth Wing", "Rebecca Yarros", "fourth-wing", ReadingStatus.TO_READ, 1, genre = BookGenre.FANTASY),
        book("t2", "La Horde du Contrevent", "Alain Damasio", "horde-du-contrevent", ReadingStatus.TO_READ, 6),
        book("t3", "Le Problème à trois corps", "Liu Cixin", "trois-corps", ReadingStatus.TO_READ, 20),
        book("t4", "Fondation", "Isaac Asimov", "fondation", ReadingStatus.TO_READ, 45),
        book("t5", "Dune", "Frank Herbert", "dune", ReadingStatus.TO_READ, 400),
    )

    val dashboard = Dashboard(
        currentYear = 2026,
        booksPerYear = listOf(2022 to 9, 2023 to 14, 2024 to 21, 2025 to 16, 2026 to 18).map { Dashboard.YearCount(it.first, it.second) },
        pagesPerMonth = listOf(410, 720, 380, 910, 760, 600, 1180, 1100, 260, 840, 0, 0).mapIndexed { i, p -> Dashboard.MonthPages(i + 1, p) },
        hoursPerMonth = listOf(6, 11, 4, 0, 9, 14, 7, 12, 3, 5, 0, 0).mapIndexed { i, h -> Dashboard.MonthHours(i + 1, h) },
        reading = reading,
        toRead = toRead,
        toReadCount = 27,
        readCount = 142,
        pagesRead = 41_230,
        hoursListened = 212,
        genres = listOf(BookGenre.SCIENCE_FICTION to 48, BookGenre.FANTASY to 39, BookGenre.CRIME to 17, null to 38).map { Dashboard.GenreSlice(it.first, it.second) },
        lastFinished = reading.first().copy(id = "f1", status = ReadingStatus.READ, rating = 4.5, startedAt = ago(20), finishedAt = ago(3)),
        series = listOf(
            Dashboard.SeriesProgress("one-piece", "One Piece", readCount = 107, totalCount = 111, favorite = true, coverURL = cover("one-piece-107")),
            Dashboard.SeriesProgress("frieren", "Frieren", readCount = 5, totalCount = 15, coverURL = cover("frieren-05")),
            Dashboard.SeriesProgress("blacksad", "Blacksad", readCount = 4, totalCount = 7, rating = 4.5, coverURL = cover("blacksad-04")),
            Dashboard.SeriesProgress("hyperion", "Les Cantos d'Hypérion", isAudio = true, readCount = 1, totalCount = 4, coverURL = cover("hyperion-audio-01")),
            Dashboard.SeriesProgress("blue-lock", "Blue Lock", readCount = 20, totalCount = 35, coverURL = cover("blue-lock-20")),
        ),
        favoriteCount = 15,
        hasAudiobooks = true,
        libraryIsEmpty = false,
    )

    val discoveries = MonthlyDiscoveries(
        month = MonthlyDiscoveries.month(Instant.now()),
        suggestions = listOf(
            Suggestion(
                id = "s1", format = ReleaseFormat.BOOK, title = "Les Dépossédés", originalTitle = "The Dispossessed", originalLanguage = BookLanguage.EN,
                authors = listOf("Ursula K. Le Guin"), reason = "Parce que vous avez aimé La Main gauche de la nuit.", short = "", references = emptyList(),
                state = AwaitedState.AVAILABLE, watched = false, date = null, coverURL = cover("depossedes"), storeURL = null,
                awaitableFormats = emptyList(), awaitedEditionId = null,
            ),
            Suggestion(
                id = "s2", format = ReleaseFormat.BOOK, title = "Neuromancien", originalTitle = "Neuromancer", originalLanguage = BookLanguage.EN,
                authors = listOf("William Gibson"), reason = "Pour prolonger Les Furtifs.", short = "", references = emptyList(),
                state = AwaitedState.AVAILABLE, watched = false, date = null, coverURL = cover("neuromancien"), storeURL = null,
                awaitableFormats = listOf(ReleaseFormat.AUDIOBOOK), awaitedEditionId = null,
            ),
        ),
    )

    val genreInsights = com.polyforms.shiori.features.home.GenreInsights(
        readCount = 142,
        shares = listOf(BookGenre.SCIENCE_FICTION to 48, BookGenre.FANTASY to 39, BookGenre.CRIME to 17, BookGenre.LITERARY_FICTION to 14, BookGenre.HISTORY to 9, BookGenre.HORROR to 6)
            .map { com.polyforms.shiori.features.home.GenreInsights.Share(it.first, it.second) },
        formats = listOf(
            com.polyforms.shiori.features.home.GenreInsights.FormatShare(BookFormat.BOOK, 92, BookGenre.SCIENCE_FICTION),
            com.polyforms.shiori.features.home.GenreInsights.FormatShare(BookFormat.MANGA, 31, BookGenre.FANTASY),
            com.polyforms.shiori.features.home.GenreInsights.FormatShare(BookFormat.AUDIOBOOK, 19, BookGenre.FANTASY),
        ),
        tastes = listOf(
            com.polyforms.shiori.features.home.GenreInsights.Taste(BookGenre.SCIENCE_FICTION, readCount = 48, averageRating = 4.3),
            com.polyforms.shiori.features.home.GenreInsights.Taste(BookGenre.FANTASY, readCount = 39, averageRating = 4.0),
            com.polyforms.shiori.features.home.GenreInsights.Taste(BookGenre.CRIME, readCount = 17, averageRating = 3.6),
            com.polyforms.shiori.features.home.GenreInsights.Taste(BookGenre.HORROR, readCount = 6, averageRating = 4.7),
            com.polyforms.shiori.features.home.GenreInsights.Taste(BookGenre.HISTORY, readCount = 9, averageRating = 3.2),
        ),
        averageRating = 4.0,
        gem = com.polyforms.shiori.features.home.GenreInsights.Taste(BookGenre.HORROR, readCount = 6, averageRating = 4.7),
        longest = com.polyforms.shiori.features.home.GenreInsights.LongestRecord(BookGenre.FANTASY, 612),
        fastest = com.polyforms.shiori.features.home.GenreInsights.FastestRecord(BookGenre.CRIME, 5),
        mostDropped = com.polyforms.shiori.features.home.GenreInsights.DroppedRecord(BookGenre.HISTORY, 3, 12),
        unexplored = listOf(
            com.polyforms.shiori.features.home.GenreInsights.Unexplored(BookGenre.POETRY, 2),
            com.polyforms.shiori.features.home.GenreInsights.Unexplored(BookGenre.COOKING, 0),
            com.polyforms.shiori.features.home.GenreInsights.Unexplored(BookGenre.TRAVEL, 0),
        ),
    )

    val reviewDraft = com.polyforms.shiori.features.book.BookDraft(
        title = "La Horde du Contrevent",
        authors = listOf("Alain Damasio"),
        publisher = "Folio",
        firstPublishedIn = 2004,
        synopsis = "Imaginez une Terre poncée, avec en son centre une bande de cinq cents kilomètres de large et de cinq mille de long, battue par un vent continu. Vingt-trois hordiers remontent ce vent jusqu'à sa source.",
        genre = BookGenre.SCIENCE_FICTION,
        subgenres = listOf("Aventure"),
        pageCount = 736,
        isbn13 = "9782070342266",
        language = BookLanguage.FR,
        coverURL = cover("horde-du-contrevent"),
    )

    val coverSlugs = (reading + toRead).mapNotNull { it.coverURL?.substringAfterLast('/')?.removeSuffix(".jpg") } +
        listOf("one-piece-107", "frieren-05", "blacksad-04", "hyperion-audio-01", "blue-lock-20", "depossedes", "neuromancien")
}
