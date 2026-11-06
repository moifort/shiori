package com.polyforms.shiori.features.discover

import com.polyforms.shiori.features.friends.LovedBook
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.features.book.BookDraft
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.ReleaseDateText
import com.polyforms.shiori.shared.SeriesMembership
import com.polyforms.shiori.shared.SystemTint
import com.polyforms.shiori.shared.VolumeKind
import java.text.Collator
import java.time.Instant

/** The sagas of both formats, null until neither format was ever loaded. */
val DiscoveryFeed.sagas: List<SagaDiscovery>?
    get() = if (rows.isEmpty()) null else ReleaseFormat.entries.flatMap { rows[it] ?: emptyList() }

private val collator: Collator get() = Collator.getInstance()

/** The sagas with a volume announced, the soonest first, the undated last. */
val DiscoveryFeed.upcoming: List<SagaDiscovery>
    get() = (sagas ?: emptyList()).filter { it.releases.next != null }.sortedWith { lhs, rhs ->
        val left = lhs.releases.next?.date?.let(ReleaseDateText::lastDay)
        val right = rhs.releases.next?.date?.let(ReleaseDateText::lastDay)
        when {
            left == right -> collator.compare(lhs.series.name, rhs.series.name)
            left == null -> 1
            right == null -> -1
            else -> left.compareTo(right)
        }
    }

/** Every volume just out, the newest first. */
val DiscoveryFeed.recentVolumes: List<DiscoveryVolume>
    get() = (sagas ?: emptyList()).flatMap { saga -> saga.recent.map { DiscoveryVolume(saga, it) } }
        .sortedWith(compareByDescending<DiscoveryVolume> { it.volume.date ?: "" }.thenByDescending { it.volume.number })

/** The sagas with a volume just out, the newest first. */
val DiscoveryFeed.recentSagas: List<SagaDiscovery>
    get() = (sagas ?: emptyList()).filter { it.recent.isNotEmpty() }.sortedByDescending { it.recent.firstOrNull()?.date ?: "" }

/** "Nouveautés séries": the volumes just out, then the ones announced. */
val DiscoveryFeed.seriesNews: List<DiscoveryVolume>
    get() = recentVolumes + upcoming.mapNotNull { saga -> saga.releases.next?.let { DiscoveryVolume(saga, it) } }

private val DiscoveryFeed.authorNews: List<AuthorNews>
    get() {
        val order = mutableListOf<String>()
        val parts = mutableMapOf<String, MutableList<AuthorNews.Part>>()
        for (format in ReleaseFormat.entries) {
            for (row in authors[format] ?: emptyList()) {
                if (row.author.id !in parts) order += row.author.id
                parts.getOrPut(row.author.id) { mutableListOf() } += AuthorNews.Part(format, row)
            }
        }
        return order.mapNotNull { id -> parts[id]?.let(::AuthorNews) }
    }

/** The authors with something announced, the soonest first. */
val DiscoveryFeed.upcomingAuthors: List<AuthorNews>
    get() = authorNews.filter { it.hasComing }.sortedWith { lhs, rhs ->
        val left = lhs.soonestComing
        val right = rhs.soonestComing
        when {
            left == right -> collator.compare(lhs.author.name, rhs.author.name)
            left == null -> 1
            right == null -> -1
            else -> left.compareTo(right)
        }
    }

/** The authors with something just out, the newest first. */
val DiscoveryFeed.recentAuthors: List<AuthorNews>
    get() = authorNews.filter { it.hasOut }.sortedByDescending { it.newestOut ?: "" }

/** "Bientôt disponible": the editions awaited in both formats, in the order the strip shows. */
val DiscoveryFeed.awaitedSoon: List<AwaitedEdition>
    get() = ReleaseFormat.entries.flatMap { awaited[it] ?: emptyList() }.soonOrder

fun DiscoveryFeed.holdsNothing(format: ReleaseFormat): Boolean = followed[format] == 0 && (awaited[format] ?: emptyList()).isEmpty()

/** The format the award winners and the month's discoveries are shown in. */
val DiscoveryFeed.awardsFormat: ReleaseFormat
    get() = if (holdsNothing(ReleaseFormat.BOOK) && !holdsNothing(ReleaseFormat.AUDIOBOOK)) ReleaseFormat.AUDIOBOOK else ReleaseFormat.BOOK

/** Announced first, the soonest first; then out, the newest first; then looked for, the latest awaited first. */
val List<AwaitedEdition>.soonOrder: List<AwaitedEdition>
    get() {
        fun rank(edition: AwaitedEdition) = when (edition.state) {
            AwaitedState.ANNOUNCED -> 0
            AwaitedState.AVAILABLE -> 1
            else -> 2
        }
        fun day(edition: AwaitedEdition) = edition.date?.let(ReleaseDateText::lastDay)
        return sortedWith { lhs, rhs ->
            val (left, right) = rank(lhs) to rank(rhs)
            if (left != right) return@sortedWith left.compareTo(right)
            val byDate = when (left) {
                0, 1 -> {
                    val (l, r) = day(lhs) to day(rhs)
                    when {
                        l == r -> 0
                        l == null -> 1
                        r == null -> -1
                        left == 0 -> l.compareTo(r)
                        else -> r.compareTo(l)
                    }
                }
                else -> (rhs.awaitedAt ?: Instant.MIN).compareTo(lhs.awaitedAt ?: Instant.MIN)
            }
            if (byDate != 0) byDate else collator.compare(lhs.title, rhs.title)
        }
    }

val DiscoveryVolume.isComing: Boolean get() = volume.date?.let { ReleaseDateText.isUpcoming(it) } ?: true

val DiscoveryVolume.caption: String get() = volume.date?.let(ReleaseDateText::short) ?: L("Annoncé")

/** The volume drawn as a book: its cover, its title, the saga's author. */
val DiscoveryVolume.cover: Book
    get() {
        val series = saga.series
        return Book(
            id = "release-${series.id}-${volume.number}",
            title = volume.title,
            authors = listOfNotNull(series.author),
            format = if (series.isAudio) BookFormat.AUDIOBOOK else BookFormat.BOOK,
            language = series.language,
            coverURL = volume.coverURL,
            status = ReadingStatus.TO_READ,
        )
    }

/** The volume as its page describes it: the cover, its ISBN and its place in the saga. */
val DiscoveryVolume.book: Book
    get() = cover.copy(isbn13 = volume.isbn13, series = SeriesMembership(saga.series.seriesId, saga.series.name, volume.number, VolumeKind.MAIN))

val DiscoveryVolume.seed: ReleaseSeed
    get() {
        val book = book
        return ReleaseSeed(book.title, book.authors, book.format, book.language, book.series, volume.isbn13, volume.date, volume.coverURL)
    }

/** The shelf entry a described volume becomes, onto the pile. */
fun DiscoveryVolume.draft(shown: Book): BookDraft = BookDraft(
    title = shown.title,
    authors = shown.authors,
    format = shown.format,
    genre = shown.genre ?: saga.series.genre,
    subgenres = shown.subgenres,
    synopsis = shown.synopsis,
    publisher = shown.publisher,
    firstPublishedIn = shown.firstPublishedIn,
    pageCount = shown.pageCount,
    isbn13 = shown.isbn13,
    language = saga.series.language,
    series = shown.series,
    coverURL = shown.coverURL,
    status = ReadingStatus.TO_READ,
)

/** A line of the Books shelf's summary card. */
enum class DiscoverCategory {
    SOON, AWARDS, FRIENDS;

    val title: String
        get() = when (this) {
            SOON -> L("Bientôt disponible")
            AWARDS -> L("Prix littéraires")
            FRIENDS -> L("Coups de cœur")
        }

    val symbol: String
        get() = when (this) {
            SOON -> "clock.fill"
            AWARDS -> "trophy.fill"
            FRIENDS -> "heart.fill"
        }

    val tint: SystemTint
        get() = when (this) {
            SOON -> SystemTint.ORANGE
            AWARDS -> SystemTint.YELLOW
            FRIENDS -> SystemTint.RED
        }
}

/** What each line of the summary card says under its name. */
object DiscoverSummaryLine {
    fun soon(editions: List<AwaitedEdition>): String {
        val date = editions.mapNotNull { it.announcedDate }.minByOrNull(ReleaseDateText::lastDay)
        if (date != null) return L("Prochain : %@", ReleaseDateText.short(date))
        return if (editions.size == 1) L("1 livre attendu") else L("%lld livres attendus", editions.size)
    }

    fun awards(sections: List<AwardSection>): String = sections.joinToString(" · ") { it.genre.label }

    fun friends(books: List<LovedBook>): String {
        val names = books.flatMap { it.lovers.friends }.map { it.displayName }.distinct()
        return when (names.size) {
            0 -> ""
            1 -> names[0]
            2 -> L("%@ et %@", names[0], names[1])
            else -> "${names[0]}, ${names[1]} +${names.size - 2}"
        }
    }
}

/** One cover of an author's news: a work the web found, an edition awaited, a saga's volume. */
data class AuthorNewsItem(
    val id: String,
    val title: String,
    val date: String?,
    val coverURL: String?,
    val isComing: Boolean,
    val isAudio: Boolean,
    val source: Source,
) {
    sealed interface Source {
        data class Work(val work: DiscoveredWork) : Source
        data class Awaited(val edition: AwaitedEdition) : Source
        data class Volume(val volume: DiscoveryVolume) : Source
    }

    companion object {
        fun ordered(works: List<Pair<DiscoveredWork, ReleaseFormat>>, awaited: List<AwaitedEdition>, volumes: List<DiscoveryVolume>, section: ReleaseSection): List<AuthorNewsItem> {
            val items = works.map { (work, format) ->
                AuthorNewsItem("work-$format-${work.id}", work.title, work.date, work.coverURL, work.date?.let { ReleaseDateText.isUpcoming(it) } ?: true, format == ReleaseFormat.AUDIOBOOK, Source.Work(work))
            } + awaited.map {
                AuthorNewsItem("awaited-${it.id}", it.title, it.date, it.coverURL, it.state != AwaitedState.AVAILABLE, it.format == ReleaseFormat.AUDIOBOOK, Source.Awaited(it))
            } + volumes.map {
                AuthorNewsItem("volume-${it.id}", it.volume.title, it.volume.date, it.volume.coverURL, section == ReleaseSection.UPCOMING, it.saga.series.isAudio, Source.Volume(it))
            }
            fun day(item: AuthorNewsItem) = item.date?.let(ReleaseDateText::lastDay)
            return when (section) {
                ReleaseSection.UPCOMING -> items.sortedWith { lhs, rhs ->
                    val (l, r) = day(lhs) to day(rhs)
                    when {
                        l == null && r == null -> 0
                        l == null -> 1
                        r == null -> -1
                        else -> l.compareTo(r)
                    }
                }
                ReleaseSection.RECENT -> items.sortedByDescending { day(it) ?: "" }
            }
        }
    }
}
