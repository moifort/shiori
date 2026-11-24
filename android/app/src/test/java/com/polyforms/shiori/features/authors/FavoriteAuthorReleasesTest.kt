package com.polyforms.shiori.features.authors

import com.polyforms.shiori.features.narrators.FavoriteNarratorReleases
import com.polyforms.shiori.features.news.ReleaseSource
import com.polyforms.shiori.features.news.UpcomingRelease
import com.polyforms.shiori.shared.BookFormat
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

class FavoriteAuthorReleasesTest {
    private val today = LocalDate.of(2026, 11, 24)

    private fun release(
        id: String,
        author: String,
        date: String?,
        source: ReleaseSource = ReleaseSource.SAGA,
        hearted: Boolean = false,
    ) = UpcomingRelease(
        id = id,
        source = source,
        format = BookFormat.BOOK,
        title = id,
        authors = listOf(author),
        date = date,
        coverURL = null,
        seriesName = null,
        volume = null,
        author = if (source == ReleaseSource.AUTHOR) UpcomingRelease.AuthorRef("k-$author", author, hearted, null) else null,
        sagaRating = null,
        sagaFavorite = false,
        narrator = if (source == ReleaseSource.NARRATOR) "Kristen Sieh" else null,
    )

    @Test
    fun keepsTheHeartedAuthorsInTheServerOrder() {
        val releases = listOf(
            release("a", "Pierce Brown", "2026-12-08"),
            release("b", "Someone Else", "2026-12-09"),
            release("c", "Brandon Sanderson", null, ReleaseSource.AUTHOR, hearted = true),
        )
        assertEquals(listOf("a", "c"), FavoriteAuthorReleases.of(releases, listOf("Pierce Brown"), today).map { it.id })
    }

    @Test
    fun matchesANameWhateverItsCaseAndAccents() {
        val releases = listOf(release("a", "Rene Barjavel", "2027"))
        assertEquals(listOf("a"), FavoriteAuthorReleases.of(releases, listOf("René BARJAVEL"), today).map { it.id })
    }

    @Test
    fun dropsWhatIsAlreadyOutButKeepsThisMonthAndTheUndated() {
        val releases = listOf(
            release("past", "Pierce Brown", "2026-11-23"),
            release("month", "Pierce Brown", "2026-11"),
            release("year", "Pierce Brown", "2026"),
            release("undated", "Pierce Brown", null),
            release("lastMonth", "Pierce Brown", "2026-10"),
        )
        assertEquals(listOf("month", "year", "undated"), FavoriteAuthorReleases.of(releases, listOf("Pierce Brown"), today).map { it.id })
    }

    @Test
    fun leavesTheNarratorsRecordingsAndDuplicatesOut() {
        val releases = listOf(
            release("a", "Pierce Brown", "2026-12-08"),
            release("a", "Pierce Brown", "2026-12-08"),
            release("n", "Pierce Brown", "2026-12-10", ReleaseSource.NARRATOR),
        )
        assertEquals(listOf("a"), FavoriteAuthorReleases.of(releases, listOf("Pierce Brown"), today).map { it.id })
        assertEquals(listOf("n"), FavoriteNarratorReleases.of(releases, today).map { it.id })
    }

    @Test
    fun showsNothingWithoutAHeartedAuthor() {
        assertTrue(FavoriteAuthorReleases.of(listOf(release("a", "Pierce Brown", "2027")), emptyList(), today).isEmpty())
    }

    @Test
    fun aSnapshotOpensOnWhatIsStillAhead() {
        val releases = listOf(release("past", "A", "2026-11-01"), release("ahead", "A", "2026-12-01"))
        assertEquals(listOf("ahead"), FavoriteAuthorReleases.stillAhead(releases, today).map { it.id })
    }
}
