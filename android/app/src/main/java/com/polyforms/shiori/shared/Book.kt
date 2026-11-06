@file:UseSerializers(InstantSerializer::class)

package com.polyforms.shiori.shared

import kotlinx.serialization.Serializable
import kotlinx.serialization.UseSerializers
import java.time.Instant

/**
 * Where a book stands for its reader, in the order the pile is worked through. `DROPPED` is a
 * book stopped for good: set from the book's menu rather than the segmented picker.
 */
@Serializable
enum class ReadingStatus {
    TO_READ, READING, READ, DROPPED;

    val label: String
        get() = when (this) {
            TO_READ -> L("À lire")
            READING -> L("En cours")
            READ -> L("Lu")
            DROPPED -> L("Abandonné")
        }

    /** One symbol per status, everywhere the status is drawn. */
    val symbol: String
        get() = when (this) {
            TO_READ -> "bookmark.fill"
            READING -> "book.fill"
            READ -> "checkmark"
            DROPPED -> "hand.thumbsdown.fill"
        }

    companion object {
        /** The states a book moves through, as the picker offers them. */
        val progression = listOf(TO_READ, READING, READ)
    }
}

/** What kind of object the reader holds. Paper or screen is `BookMedium`. */
@Serializable
enum class BookFormat {
    BOOK, AUDIOBOOK, BANDE_DESSINEE, COMIC, MANGA;

    val label: String
        get() = when (this) {
            BOOK -> L("Livre")
            AUDIOBOOK -> L("Livre audio")
            BANDE_DESSINEE -> L("BD")
            COMIC -> L("Comics")
            MANGA -> L("Manga")
        }

    val symbol: String
        get() = when (this) {
            BOOK -> "book.closed"
            AUDIOBOOK -> "headphones"
            BANDE_DESSINEE -> "text.bubble"
            COMIC -> "bolt"
            MANGA -> "character.book.closed.ja"
        }
}

/** Where a read book is held: on paper, on a screen, or both — one record either way. */
@Serializable
enum class BookMedium {
    PRINT, DIGITAL;

    val label: String
        get() = when (this) {
            PRINT -> L("Papier")
            DIGITAL -> L("Numérique")
        }

    val symbol: String
        get() = when (this) {
            PRINT -> "book.closed"
            DIGITAL -> "ipad"
        }

    companion object {
        /** The media as the book sheet names them: "Papier · Numérique". */
        fun label(media: List<BookMedium>): String =
            entries.filter { it in media }.joinToString(" · ") { it.label }
    }
}

/** What a book is about, from the closed list the server holds. */
@Serializable
enum class BookGenre {
    FANTASY, SCIENCE_FICTION, HORROR, CRIME, THRILLER, ROMANCE, HISTORICAL_FICTION, ADVENTURE,
    LITERARY_FICTION, HUMOR, POETRY, DRAMA, BIOGRAPHY, HISTORY, ESSAY, SCIENCE, SELF_HELP,
    BUSINESS, ART, COOKING, TRAVEL, OTHER;

    val label: String
        get() = when (this) {
            FANTASY -> L("Fantastique")
            SCIENCE_FICTION -> L("Science-fiction")
            HORROR -> L("Horreur")
            CRIME -> L("Polar")
            THRILLER -> L("Thriller")
            ROMANCE -> L("Romance")
            HISTORICAL_FICTION -> L("Roman historique")
            ADVENTURE -> L("Aventure")
            LITERARY_FICTION -> L("Littérature")
            HUMOR -> L("Humour")
            POETRY -> L("Poésie")
            DRAMA -> L("Théâtre")
            BIOGRAPHY -> L("Biographie")
            HISTORY -> L("Histoire")
            ESSAY -> L("Essai")
            SCIENCE -> L("Sciences")
            SELF_HELP -> L("Développement personnel")
            BUSINESS -> L("Économie")
            ART -> L("Art")
            COOKING -> L("Cuisine")
            TRAVEL -> L("Voyage")
            OTHER -> L("Autre")
        }

    /** The genre under a cover, where a third of the screen leaves little room. */
    val shortLabel: String
        get() = when (this) {
            SCIENCE_FICTION -> L("SF")
            HISTORICAL_FICTION -> L("Historique")
            SELF_HELP -> L("Dév. perso")
            else -> label
        }

    /** One symbol per genre, as Apple Books draws its genres. */
    val symbol: String
        get() = when (this) {
            FANTASY -> "lizard.fill"
            SCIENCE_FICTION -> "rocket"
            HORROR -> "ghost"
            CRIME -> "magnifyingglass"
            THRILLER -> "eye.fill"
            ROMANCE -> "camera.macro"
            HISTORICAL_FICTION -> "crown.fill"
            ADVENTURE -> "map.fill"
            LITERARY_FICTION -> "text.book.closed.fill"
            HUMOR -> "face.smiling.inverse"
            POETRY -> "feather"
            DRAMA -> "theatermasks.fill"
            BIOGRAPHY -> "person.bust.fill"
            HISTORY -> "building.columns.fill"
            ESSAY -> "brain.head.profile.fill"
            SCIENCE -> "atom"
            SELF_HELP -> "leaf.fill"
            BUSINESS -> "chart.line.uptrend.xyaxis"
            ART -> "paintpalette.fill"
            COOKING -> "fork.knife"
            TRAVEL -> "balloon.fill"
            OTHER -> "tag.fill"
        }

    /** The colour a genre's chip takes, by name of the iOS system colour. */
    val tint: SystemTint
        get() = when (this) {
            FANTASY, DRAMA -> SystemTint.PURPLE
            SCIENCE_FICTION -> SystemTint.INDIGO
            HORROR -> SystemTint.RED
            CRIME, HISTORICAL_FICTION, HISTORY -> SystemTint.BROWN
            THRILLER, HUMOR, COOKING -> SystemTint.ORANGE
            ROMANCE, ART -> SystemTint.PINK
            ADVENTURE, BUSINESS -> SystemTint.GREEN
            LITERARY_FICTION, TRAVEL -> SystemTint.TEAL
            POETRY, SELF_HELP -> SystemTint.MINT
            BIOGRAPHY, SCIENCE -> SystemTint.BLUE
            ESSAY -> SystemTint.CYAN
            OTHER -> SystemTint.GRAY
        }

    companion object {
        /** By label in the reader's language, `OTHER` last. */
        val alphabetical: List<BookGenre>
            get() = entries.filter { it != OTHER }
                .sortedWith(compareBy(java.text.Collator.getInstance()) { it.label }) + OTHER
    }
}

/** The iOS system colours a model can name without depending on Compose. */
enum class SystemTint { BLUE, GREEN, RED, ORANGE, YELLOW, PINK, PURPLE, INDIGO, TEAL, CYAN, MINT, BROWN, GRAY }

/** Where a volume sits in a saga. Only `MAIN` belongs to the numbered spine. */
@Serializable
enum class VolumeKind {
    MAIN, PREQUEL, SPIN_OFF, NOVELLA, COMPANION;

    val label: String
        get() = when (this) {
            MAIN -> L("Tome")
            PREQUEL -> L("Préquelle")
            SPIN_OFF -> L("Hors-série")
            NOVELLA -> L("Nouvelle")
            COMPANION -> L("Compagnon")
        }
}

/** Where the reader stands on a saga, in the order a filter lists them. */
@Serializable
enum class SeriesState {
    NOT_STARTED, IN_PROGRESS, COMPLETE, UNFOLLOWED;

    val label: String
        get() = when (this) {
            NOT_STARTED -> L("À lire")
            IN_PROGRESS -> L("En cours")
            COMPLETE -> L("Terminée")
            UNFOLLOWED -> L("Non suivie")
        }

    val shelfTitle: String
        get() = when (this) {
            NOT_STARTED -> L("À lire")
            IN_PROGRESS -> L("En cours")
            COMPLETE -> L("Terminées")
            UNFOLLOWED -> L("Non suivies")
        }

    val symbol: String
        get() = when (this) {
            NOT_STARTED -> ReadingStatus.TO_READ.symbol
            IN_PROGRESS -> ReadingStatus.READING.symbol
            COMPLETE -> ReadingStatus.READ.symbol
            UNFOLLOWED -> "eye.slash"
        }
}

/** A book's place in a saga, carried on the book itself so a list can group without fetching. */
@Serializable
data class SeriesMembership(
    val id: String,
    val name: String,
    val volume: Int?,
    val kind: VolumeKind,
    val annexNumber: Int? = null,
) {
    val isAnnex: Boolean get() = kind != VolumeKind.MAIN

    /** "Tome 3", or just the kind when it sits outside the numbering. */
    val label: String get() = if (volume == null) kind.label else "${kind.label} $volume"
}

/** Who recommended a book, and what they said of it. Either half may be missing, never both. */
@Serializable
data class BookRecommendation(val recommenderName: String? = null, val comment: String? = null)

/** A book as its reader holds it: the public facts and their own judgment on one record. */
@Serializable
data class Book(
    val id: String,
    val title: String,
    val authors: List<String>,
    val authorKeys: List<String>? = null,
    val format: BookFormat = BookFormat.BOOK,
    val media: List<BookMedium> = listOf(BookMedium.PRINT),
    val publisher: String? = null,
    val firstPublishedIn: Int? = null,
    val editionYear: Int? = null,
    val synopsis: String? = null,
    val genre: BookGenre? = null,
    val subgenres: List<String> = emptyList(),
    val pageCount: Int? = null,
    val currentPage: Int? = null,
    val durationMinutes: Int? = null,
    val narrators: List<String> = emptyList(),
    val narratorKeys: List<String>? = null,
    val listeningProgress: Int? = null,
    val audibleURL: String? = null,
    val amazonURL: String? = null,
    val isbn13: String? = null,
    val language: BookLanguage? = null,
    val series: SeriesMembership? = null,
    val forthcoming: Boolean = false,
    val coverURL: String? = null,
    val status: ReadingStatus,
    val rating: Double? = null,
    val seriesRating: Double? = null,
    val favorite: Boolean = false,
    val note: String? = null,
    val recommendation: BookRecommendation? = null,
    val hidden: Boolean = false,
    val awaitingDescription: Boolean = false,
    val addedAt: Instant? = null,
    val startedAt: Instant? = null,
    val finishedAt: Instant? = null,
    val shelvedAt: Instant? = null,
    val statusChangedAt: Instant? = null,
) {
    /** The stars a row draws: the book's own rating, else its saga's. */
    val shownRating: Double? get() = rating ?: seriesRating

    /** The stars drawn are the saga's: drawn dimmer. */
    val ratingIsInherited: Boolean get() = rating == null && seriesRating != null

    val narratorLine: String? get() = if (narrators.isEmpty()) null else narrators.joinToString(", ")

    /** "8h12", "47min". */
    val durationLabel: String?
        get() {
            val total = durationMinutes ?: return null
            val hours = total / 60
            val minutes = total % 60
            if (hours == 0) return L("%lldmin", minutes)
            if (minutes == 0) return L("%lldh", hours)
            return L("%lldh%@", hours, "%02d".format(minutes))
        }

    val listeningProgressLabel: String? get() = listeningProgress?.let { "$it%" }

    val unfinishedListeningProgress: Int?
        get() = if (status == ReadingStatus.READING || status == ReadingStatus.DROPPED) listeningProgress else null

    val readingProgress: Int?
        get() {
            val page = currentPage ?: return null
            val count = pageCount ?: return null
            if (count <= 0) return null
            return minOf(100, page * 100 / count)
        }

    val unfinishedReadingPage: Int?
        get() {
            if (format == BookFormat.AUDIOBOOK) return null
            if (status != ReadingStatus.READING && status != ReadingStatus.DROPPED) return null
            return currentPage
        }

    val tracksPages: Boolean get() = format != BookFormat.AUDIOBOOK && status == ReadingStatus.READING

    val authorLine: String
        get() = if (authors.isEmpty()) L("Auteur inconnu") else authors.joinToString(", ")
}

/** One place in a saga's cover strip: a volume owned, or one lacked, drawn dimmed. */
@Serializable
sealed interface SeriesStripItem {
    val id: String

    @Serializable
    data class Owned(val book: Book) : SeriesStripItem {
        override val id: String get() = book.id
    }

    @Serializable
    data class Missing(
        val key: String,
        val number: Int?,
        val title: String,
        val forthcoming: Boolean,
        val date: String? = null,
        val coverURL: String? = null,
    ) : SeriesStripItem {
        override val id: String get() = "missing-$key"
    }

    companion object {
        /** The saga's spine in order: each volume takes the reader's books, or a placeholder. */
        fun strip(
            owned: List<Book>,
            spine: List<Volume>,
            currentYear: Int,
            language: BookLanguage? = null,
            catalogedAt: Instant? = null,
        ): List<SeriesStripItem> {
            if (spine.isEmpty()) return owned.map { Owned(it) }
            val datedUpTo = spine.datedUpTo(language, catalogedAt)
            val placed = mutableSetOf<String>()
            val items = mutableListOf<SeriesStripItem>()
            for (volume in spine) {
                val books = owned.filter { it.id !in placed && volume.matches(it) }
                if (books.isNotEmpty()) {
                    items += books.map { Owned(it) }
                    placed += books.map { it.id }
                } else {
                    val release = language?.let { volume.release(it) }
                    items += Missing(
                        key = volume.id,
                        number = volume.number,
                        title = release?.title ?: volume.title,
                        forthcoming = volume.isForthcoming(currentYear, language, datedUpTo),
                        date = release?.date,
                        coverURL = release?.coverURL,
                    )
                }
            }
            return items
        }

        /** The strip, then the books held off the spine. */
        fun sagaRow(
            owned: List<Book>,
            spine: List<Volume>,
            currentYear: Int,
            language: BookLanguage? = null,
            catalogedAt: Instant? = null,
        ): List<SeriesStripItem> {
            val items = strip(owned, spine, currentYear, language, catalogedAt)
            val placed = items.map { it.id }.toSet()
            return items + owned.filter { it.id !in placed }.map { Owned(it) }
        }
    }
}

/** One entry of a saga catalogue, owned or not. */
@Serializable
data class Volume(
    val number: Int?,
    val title: String,
    val publishedIn: Int?,
    val kind: VolumeKind,
    val releases: List<VolumeRelease> = emptyList(),
) {
    val id: String get() = "${kind.name.lowercase()}-${number?.toString() ?: title}"

    fun release(language: BookLanguage): VolumeRelease? = releases.firstOrNull { it.language == language }

    private fun releaseDate(language: BookLanguage?): String? {
        if (language != null) return release(language)?.date
        return releases.map { it.date }.filter { it.length == 10 }.minOrNull()
    }

    /** A volume not out yet in that edition — the server's rule. */
    fun isForthcoming(year: Int, language: BookLanguage? = null, datedUpTo: Int? = null): Boolean {
        if (language?.let { release(it) } == null && datedUpTo != null && number != null && number > datedUpTo) {
            return true
        }
        val earliest = releases.map { it.date }.minByOrNull { ReleaseDateText.lastDay(it) }
        val date = releaseDate(language) ?: earliest
        if (date != null) return ReleaseDateText.isUpcoming(date)
        return publishedIn?.let { it > year } ?: false
    }

    fun counts(year: Int, language: BookLanguage? = null, datedUpTo: Int? = null): Boolean {
        if (!isForthcoming(year, language, datedUpTo)) return true
        return releaseDate(language)?.length == 10
    }

    /** Whether the reader's book is this volume: same kind at the same number, or by title. */
    fun matches(book: Book): Boolean {
        val kind = book.series?.kind ?: VolumeKind.MAIN
        if (kind != this.kind) return false
        val held = book.series?.volume
        if (number != null && held != null) return held == number
        val saga = book.series?.name
        if (number != null && saga != null && words(title) == words(saga)) return false
        return (listOf(title) + releases.map { it.title }).any { sameTitle(book.title, it) }
    }

    companion object {
        /** When the catalogues began listing only the volumes out in their edition's language. */
        val editionCataloguesSince: Instant = Instant.ofEpochSecond(1_790_852_400)

        fun words(text: String): List<String> =
            java.text.Normalizer.normalize(text.lowercase(), java.text.Normalizer.Form.NFD)
                .replace(Regex("\\p{M}+"), "")
                .split(Regex("[^\\p{L}\\p{N}]+"))
                .filter { it.isNotEmpty() }

        fun sameTitle(left: String, right: String): Boolean {
            val a = words(left)
            val b = words(right)
            if (a.isEmpty() || b.isEmpty()) return false
            val (short, long) = if (a.size <= b.size) a to b else b to a
            return long.take(short.size) == short
        }
    }
}

/** The highest volume the edition has a date for, on a catalogue built before editions split. */
fun List<Volume>.datedUpTo(language: BookLanguage?, catalogedAt: Instant? = null): Int? {
    if (language == null) return null
    if (catalogedAt != null && catalogedAt >= Volume.editionCataloguesSince) return null
    return filter { it.release(language) != null }.mapNotNull { it.number }.maxOrNull()
}

/** A volume in one language, as the weekly release watch found it. */
@Serializable
data class VolumeRelease(
    val language: BookLanguage,
    /** `YYYY`, `YYYY-MM` or `YYYY-MM-DD`. */
    val date: String,
    val title: String,
    val coverURL: String?,
)

/** The shared catalogue of a saga. */
@Serializable
data class BookSeries(
    val id: String,
    val language: BookLanguage? = null,
    val name: String,
    val author: String,
    val description: String? = null,
    val spine: List<Volume> = emptyList(),
    val relatedWorks: List<Volume> = emptyList(),
    val isProvisional: Boolean = false,
    val isAwaitingCatalogue: Boolean = false,
    val isAudio: Boolean = false,
    val catalogedAt: Instant? = null,
)

/** What one reader makes of one saga. */
@Serializable
data class SeriesOpinion(
    val seriesId: String,
    val rating: Double? = null,
    val favorite: Boolean = false,
    val volumeCount: Int? = null,
    val followed: Boolean = true,
    val unfollowedLanguages: List<BookLanguage> = emptyList(),
) {
    fun follows(language: BookLanguage?): Boolean {
        if (!followed) return false
        if (language == null) return true
        return language !in unfollowedLanguages
    }
}

/** A volume of a saga the reader does not hold, announced, as the web search found it. */
@Serializable
data class DiscoveredVolume(
    val number: Int,
    val title: String,
    val date: String?,
    val isbn13: String?,
    val coverURL: String?,
    val audibleURL: String? = null,
) {
    val id: Int get() = number
}

/** A saga the reader follows. Its identity comes from their own books, not from the catalogue. */
@Serializable
data class FollowedSeries(
    val seriesId: String,
    val name: String,
    val isAudio: Boolean = false,
    val saga: String? = null,
    val author: String?,
    val language: BookLanguage?,
    val state: SeriesState?,
    val genre: BookGenre?,
    val ownedCount: Int,
    val shelvedAt: Instant? = null,
    val volumes: List<Book> = emptyList(),
    val strip: List<SeriesStripItem> = emptyList(),
    val isCatalogued: Boolean = false,
    val opinion: SeriesOpinion? = null,
    val announced: DiscoveredVolume? = null,
) {
    val id: String get() = seriesId
}
