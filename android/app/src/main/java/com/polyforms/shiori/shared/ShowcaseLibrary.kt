package com.polyforms.shiori.shared

import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.features.library.LibraryPageResult
import com.polyforms.shiori.features.library.LibraryShelves
import com.polyforms.shiori.features.library.Pile
import com.polyforms.shiori.features.library.PilePick
import com.polyforms.shiori.features.library.PileSection
import com.polyforms.shiori.features.library.PileSectionKind
import com.polyforms.shiori.features.library.ShelfQuery
import com.polyforms.shiori.features.library.ShelvesView

/**
 * The showcase library, from the previews' fixtures: enough books, sagas and an author for the
 * Library tab, its pile and its pushed pages to be walked through without a session.
 */
object ShowcaseLibrary {
    val books: List<Book> get() = DebugFixtures.reading + DebugFixtures.toRead
    val series: List<BookSeries> get() = listOf(DebugFixtures.seriesCatalogue)

    private fun Book.kept(view: ShelvesView) = (view.format == null || format == view.format) && (view.genre == null || genre == view.genre)

    fun shelves(view: ShelvesView): LibraryShelves {
        val kept = books.filter { it.kept(view) }
        return LibraryShelves(
            formats = books.map { it.format }.distinct(),
            recent = kept,
            toRead = kept.filter { it.status == ReadingStatus.TO_READ },
            series = DebugFixtures.followedSeries,
            authors = listOf(DebugFixtures.author),
        )
    }

    fun lovedSeries(): List<FollowedSeries> = DebugFixtures.followedSeries.take(2)

    fun shelfPage(query: ShelfQuery): LibraryPageResult {
        val status = query.serverStatus
        val kept = books.filter { it.kept(query.view) && (status == null || it.status == status) && (!query.favorite || it.favorite) }
        return LibraryPageResult(kept, false)
    }

    fun pile(view: ShelvesView): Pile {
        val kept = books.filter { it.kept(view) }
        return Pile(
            formats = books.map { it.format }.distinct(),
            genres = BookGenre.alphabetical.filter { genre -> books.any { it.genre == genre } },
            sections = listOf(
                PileSection(PileSectionKind.TO_FINISH, kept.filter { it.status == ReadingStatus.READING }.map { PilePick(it) }),
                PileSection(PileSectionKind.RECOMMENDED, kept.filter { it.status == ReadingStatus.TO_READ }.map { PilePick(it) }),
            ).filter { it.picks.isNotEmpty() },
        )
    }
}
