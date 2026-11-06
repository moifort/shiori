package com.polyforms.shiori.features.library

import com.polyforms.shiori.features.authors.FollowedAuthor
import com.polyforms.shiori.features.discover.AwardMention
import com.polyforms.shiori.features.narrators.NarratorRow
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookGenre
import com.polyforms.shiori.shared.FollowedSeries
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.book.PosterLabel
import kotlinx.serialization.Serializable
import java.time.Instant

/** The cut the shelves are drawn in: a format, a genre, a subgenre. */
@Serializable
data class ShelvesView(val format: BookFormat? = null, val genre: BookGenre? = null, val subgenre: String? = null) {
    val cacheKey: String get() = listOf(format?.name?.lowercase() ?: "all", genre?.name?.lowercase() ?: "any", subgenre ?: "any").joinToString("-")
}

@Serializable
data class GenreShelf(val genre: BookGenre, val count: Int, val coverURL: String? = null) {
    val id: BookGenre get() = genre
}

@Serializable
data class LibraryShelves(
    val formats: List<BookFormat> = emptyList(),
    val recent: List<Book> = emptyList(),
    val toRead: List<Book> = emptyList(),
    val readRecently: List<Book> = emptyList(),
    val favorites: List<Book> = emptyList(),
    val genres: List<GenreShelf> = emptyList(),
    val subgenres: List<String> = emptyList(),
    val series: List<FollowedSeries> = emptyList(),
    val authors: List<FollowedAuthor> = emptyList(),
    val narrators: List<NarratorRow> = emptyList(),
) {
    val isEmpty: Boolean get() = recent.isEmpty()
}

@Serializable
enum class BookShelf {
    RECENT, TO_READ, READ, LOVED, DROPPED, ALL;

    val title: String
        get() = when (this) {
            RECENT -> L("Récemment")
            TO_READ -> L("Pile à lire")
            READ -> L("Lus récemment")
            LOVED -> L("Coups de cœur")
            DROPPED -> L("Abandonnés")
            ALL -> L("Tous les livres")
        }

    val status: ReadingStatus?
        get() = when (this) {
            TO_READ -> ReadingStatus.TO_READ
            READ -> ReadingStatus.READ
            DROPPED -> ReadingStatus.DROPPED
            else -> null
        }

    val context: PosterLabel.Context
        get() = when (this) {
            RECENT -> PosterLabel.Context.JOURNAL
            TO_READ -> PosterLabel.Context.PILE
            READ -> PosterLabel.Context.READ
            LOVED -> PosterLabel.Context.LOVED_BY_AUTHOR
            DROPPED -> PosterLabel.Context.DROPPED
            ALL -> PosterLabel.Context.RECENT
        }
}

data class ShelfQuery(val shelf: BookShelf, val view: ShelvesView = ShelvesView(), val status: ReadingStatus? = null) {
    val serverStatus: ReadingStatus? get() = status ?: shelf.status
    val favorite: Boolean get() = shelf == BookShelf.LOVED
}

data class LibraryPageResult(val books: List<Book>, val hasMore: Boolean)

/** A filter of the Library tab: a status, or the loved. */
sealed interface LibraryFilter {
    data class Status(val status: ReadingStatus) : LibraryFilter
    data object Favorites : LibraryFilter

    val statusOrNull: ReadingStatus? get() = (this as? Status)?.status
    val symbol: String get() = if (this is Status) status.symbol else "heart.fill"
    val title: String get() = if (this is Status) status.shelfTitle else L("Favoris")
    fun keeps(book: Book): Boolean = if (this is Status) book.status == status else book.favorite
}

/** What another tab asked the Library to show. */
data class LibraryRequest(val mode: LibraryMode = LibraryMode.ALL, val filter: LibraryFilter? = null, val focus: String? = null)

@Serializable
enum class PileSectionKind(val graphQLName: String) {
    TO_FINISH("TO_FINISH"), NEXT_VOLUME("NEXT_VOLUME"), RECOMMENDED("RECOMMENDED"), FAVORITE_AUTHORS("FAVORITE_AUTHORS"),
    FAVORITE_NARRATORS("FAVORITE_NARRATORS"), AWARDED("AWARDED"), NEW_AUTHORS("NEW_AUTHORS");

    val title: String
        get() = when (this) {
            TO_FINISH -> L("À finir")
            NEXT_VOLUME -> L("La suite")
            RECOMMENDED -> L("Recommandés")
            FAVORITE_AUTHORS -> L("Auteurs préférés")
            FAVORITE_NARRATORS -> L("Narrateurs préférés")
            AWARDED -> L("Primés")
            NEW_AUTHORS -> L("Nouveaux auteurs")
        }
}

@Serializable
data class PilePick(val book: Book, val award: AwardMention? = null) {
    val id: String get() = book.id
}

@Serializable
data class PileSection(val kind: PileSectionKind, val picks: List<PilePick>) {
    val id: String get() = kind.graphQLName

    fun label(pick: PilePick, now: Instant = Instant.now()): PosterLabel {
        val book = pick.book
        return when (kind) {
            PileSectionKind.TO_FINISH -> {
                val progress = book.listeningProgress
                if (progress != null) return PosterLabel("$progress%", marksReading = true, progress = progress)
                val since = book.startedAt ?: book.statusChangedAt ?: book.shelvedAt
                PosterLabel(since?.let { PosterLabel.open(it, now) } ?: L("Commencé"), marksReading = true)
            }
            PileSectionKind.NEXT_VOLUME -> PosterLabel(book.series?.label ?: book.title)
            PileSectionKind.RECOMMENDED -> {
                val name = book.recommendation?.recommenderName ?: return PosterLabel(L("Recommandé"))
                PosterLabel(L("Par %@", firstName(name)))
            }
            PileSectionKind.FAVORITE_AUTHORS, PileSectionKind.NEW_AUTHORS -> PosterLabel(book.authors.firstOrNull()?.let(::surname) ?: "")
            PileSectionKind.FAVORITE_NARRATORS -> PosterLabel(book.narrators.firstOrNull()?.let(::surname) ?: "")
            PileSectionKind.AWARDED -> PosterLabel(pick.award?.let { "${it.award.stripName} ${it.year}" } ?: "")
        }
    }

    companion object {
        private val particles = setOf("le", "la", "de", "du", "des", "d'", "van", "von", "der", "den", "di", "da", "del", "dos")

        fun surname(name: String): String {
            val words = name.split(" ").filter { it.isNotEmpty() }
            if (words.size <= 1) return name
            val kept = mutableListOf(words.last())
            for (word in words.dropLast(1).reversed()) {
                if (word.lowercase() !in particles) break
                kept.add(0, word)
            }
            return kept.joinToString(" ")
        }

        fun firstName(name: String): String = name.split(" ").firstOrNull() ?: name
    }
}

@Serializable
data class Pile(val formats: List<BookFormat> = emptyList(), val genres: List<BookGenre> = emptyList(), val sections: List<PileSection> = emptyList())

/** A format's name as a Library pill: "Mangas", "Livres audio". */
val BookFormat.shelfLabel: String
    get() = when (this) {
        BookFormat.BOOK -> L("Livres")
        BookFormat.AUDIOBOOK -> L("Livres audio")
        BookFormat.BANDE_DESSINEE -> L("BD")
        BookFormat.COMIC -> L("Comics")
        BookFormat.MANGA -> L("Mangas")
    }
