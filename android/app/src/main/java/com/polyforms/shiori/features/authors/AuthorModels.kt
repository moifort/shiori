@file:UseSerializers(InstantSerializer::class)

package com.polyforms.shiori.features.authors

import com.polyforms.shiori.features.book.Change
import com.polyforms.shiori.features.discover.ReleaseFormat
import com.polyforms.shiori.features.series.SeriesProposal
import com.polyforms.shiori.features.series.cardCoverURL
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.FollowedSeries
import com.polyforms.shiori.shared.InstantSerializer
import com.polyforms.shiori.shared.L
import kotlinx.serialization.Serializable
import kotlinx.serialization.UseSerializers
import java.time.Instant

/** An author the reader holds books of, as the Authors shelf draws them. */
@Serializable
data class FollowedAuthor(
    override val key: String,
    override val name: String,
    override val indexLetter: String,
    override val portraitURL: String? = null,
    val bookCount: Int,
    val seriesCount: Int,
    val favoriteCount: Int,
    val averageRating: Double?,
    val shelvedAt: Instant?,
    override val books: List<Book>,
    override val favorite: Boolean = false,
    override val surname: String? = null,
) : ShelvedPerson {
    override val id: String get() = key
    override val initials: String get() = personInitials(name)
}

/** "RH" for "Robin Hobb": the first and last words' first letters. */
fun personInitials(name: String): String {
    val words = name.split(" ").filter { it.isNotEmpty() }
    val ends = if (words.size > 1) listOf(words.first(), words.last()) else words.take(1)
    return ends.mapNotNull { it.firstOrNull()?.toString() }.joinToString("").uppercase()
}

@Serializable
data class AuthorSeries(
    val id: String,
    val name: String,
    val isAudio: Boolean = false,
    val author: String,
    val volumeCount: Int?,
    val firstVolumeTitle: String?,
    val coverURL: String?,
) {
    val proposal: SeriesProposal get() = SeriesProposal(name, author)
}

@Serializable
data class AuthorWork(val title: String, val publishedIn: Int?, val coverURL: String?) {
    val id: String get() = title
}

/** What a person's page shows of them, from the catalogue. */
data class PersonFacts(val nationality: String? = null, val birthYear: Int? = null, val deathYear: Int? = null, val biography: String? = null)

@Serializable
data class AuthorPage(
    val author: FollowedAuthor,
    val readCount: Int,
    val nationality: String?,
    val birthYear: Int?,
    val deathYear: Int?,
    val biography: String?,
    val sagas: List<FollowedSeries>,
    val sagasNotHeld: List<AuthorSeries>,
    val books: List<Book>,
    val booksNotHeld: List<AuthorWork>,
    val isAwaitingCatalogue: Boolean = false,
) {
    val backdropURL: String?
        get() = (sagas.map { it.cardCoverURL } + books.map { it.coverURL } + sagasNotHeld.map { it.coverURL } + booksNotHeld.map { it.coverURL })
            .firstOrNull { it != null } ?: author.portraitURL

    val facts: PersonFacts get() = PersonFacts(nationality, birthYear, deathYear, biography)
}

/** An author's page to push: their key and the name to show while it loads. */
data class AuthorDestination(val key: String, val name: String, val isOffered: Boolean = false) {
    constructor(author: FollowedAuthor) : this(author.key, author.name)
}

/** A correction of a person's catalogue facts, and the portrait chosen. */
data class PersonCorrection(
    val nationality: Change<String>? = null,
    val birthYear: Change<Int>? = null,
    val deathYear: Change<Int>? = null,
    val biography: Change<String>? = null,
    val portraitURL: String? = null,
) {
    val isEmpty: Boolean get() = this == PersonCorrection()
}

/** A face the reader may give an author or a narrator. */
data class PortraitChoice(val source: Source, val url: String, val isCurrent: Boolean) {
    enum class Source { WIKIPEDIA, WIKIDATA, OPEN_LIBRARY, WEB }

    val id: String get() = url
}

/** An author page's shelf of books, printed or heard. */
enum class AuthorShelfFormat {
    PRINT, AUDIO;

    val label: String get() = if (this == PRINT) L("Livre") else L("Audio")
    val symbol: String get() = if (this == PRINT) "book.closed" else "headphones"
    fun holds(book: Book): Boolean = (book.format == BookFormat.AUDIOBOOK) == (this == AUDIO)
    val bookFormat: BookFormat get() = if (this == AUDIO) BookFormat.AUDIOBOOK else BookFormat.BOOK
    val releaseFormat: ReleaseFormat get() = if (this == AUDIO) ReleaseFormat.AUDIOBOOK else ReleaseFormat.BOOK
}

/** How the Authors shelf is ordered. */
enum class AuthorListOrder {
    RECENT, NAME, LOVED;

    val label: String
        get() = when (this) {
            NAME -> L("Alphabétique")
            RECENT -> L("Date")
            LOVED -> L("Favoris")
        }

    val icon: String
        get() = when (this) {
            NAME -> "textformat"
            RECENT -> "clock"
            LOVED -> "heart.fill"
        }
}

/** A person the reader holds books of, as the Authors and Narrators shelves draw them. */
interface ShelvedPerson {
    val id: String
    val key: String
    val name: String
    val initials: String
    val portraitURL: String?
    val books: List<Book>
    val favorite: Boolean
    val indexLetter: String
    val surname: String?
}

/** The order's label as a pill. */
val AuthorListOrder.pillLabel: String
    get() = when (this) {
        AuthorListOrder.LOVED -> L("Préférés")
        AuthorListOrder.RECENT -> L("Récents")
        AuthorListOrder.NAME -> L("A–Z")
    }
