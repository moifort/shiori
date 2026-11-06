@file:UseSerializers(InstantSerializer::class)

package com.polyforms.shiori.features.news

import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookLanguage
import com.polyforms.shiori.shared.InstantSerializer
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.account.AccountAvatar
import com.polyforms.shiori.shared.account.AvatarColor
import com.polyforms.shiori.shared.account.AvatarHero
import kotlinx.serialization.Serializable
import kotlinx.serialization.UseSerializers
import java.time.Instant
import java.time.LocalDate
import kotlin.math.roundToInt

@Serializable
enum class FeedEventKind { STARTED, FINISHED, LOVED }

/** A friend started, finished or loved a book. */
@Serializable
data class FeedEvent(
    val id: String,
    val kind: FeedEventKind,
    val at: Instant,
    val friendId: String,
    val friendName: String,
    val avatarHero: AvatarHero? = null,
    val avatarColor: AvatarColor? = null,
    val bookId: String,
    val title: String,
    val authors: List<String>,
    val format: BookFormat,
    val language: BookLanguage? = null,
    val coverURL: String?,
    val rating: Double?,
    val alsoStartedBy: Int,
    val inLibrary: Boolean,
) {
    val avatar: AccountAvatar
        get() = avatarHero?.let { AccountAvatar.Hero(it) } ?: avatarColor?.let { AccountAvatar.Tinted(it) } ?: AccountAvatar.Initials

    val cover: Book get() = Book(id = "feed-$id", title = title, authors = authors, format = format, coverURL = coverURL, status = ReadingStatus.TO_READ)
}

/** A recording a narrator the reader follows lent their voice to. */
@Serializable
data class NarratorNews(
    val id: String,
    val narratorKey: String,
    val narrator: String,
    val title: String,
    val authors: List<String>,
    val date: String,
    val coverURL: String?,
    val format: BookFormat,
    val language: BookLanguage? = null,
) {
    fun day(): LocalDate? {
        val parts = date.split("-").mapNotNull { it.toIntOrNull() }
        val year = parts.firstOrNull() ?: return null
        return runCatching { LocalDate.of(year, parts.getOrElse(1) { 1 }, parts.getOrElse(2) { 1 }) }.getOrNull()
    }

    val cover: Book get() = Book(id = "narrator-$id", title = title, authors = authors, format = BookFormat.AUDIOBOOK, coverURL = coverURL, status = ReadingStatus.TO_READ)
}

@Serializable
enum class ReleaseSource { SAGA, AUTHOR, AWAITED, NARRATOR }

/** A release to come, from a saga, an author, an edition awaited or a narrator. */
@Serializable
data class UpcomingRelease(
    val id: String,
    val source: ReleaseSource,
    val format: BookFormat,
    val title: String?,
    val authors: List<String>,
    val date: String?,
    val coverURL: String?,
    val seriesName: String?,
    val volume: Int?,
    val author: AuthorRef?,
    val sagaRating: Double?,
    val sagaFavorite: Boolean,
    val narrator: String? = null,
    val language: BookLanguage? = null,
) {
    @Serializable
    data class AuthorRef(val key: String, val name: String, val favorite: Boolean, val portraitURL: String?)

    val cover: Book get() = Book(id = "release-$id", title = title ?: "?", authors = authors, format = format, coverURL = coverURL, status = ReadingStatus.TO_READ)

    val seriesLine: String? get() = seriesName?.let { name -> volume?.let { L("%@ · Tome %lld", name, it) } ?: name }

    val shownTitle: String
        get() {
            val series = seriesName ?: return title ?: cover.title
            val own = title
            if (own == null || own.lowercase().startsWith(series.lowercase())) return series
            return own
        }

    val cardPlace: String get() = listOfNotNull(authors.firstOrNull(), volume?.let { L("Tome %lld", it) }).joinToString(" · ")

    val reason: String
        get() = when (source) {
            ReleaseSource.AUTHOR -> if (author?.favorite == true) L("Auteur favori · %@", author.name) else authors.firstOrNull() ?: ""
            ReleaseSource.SAGA -> when {
                sagaFavorite -> L("Série en coup de cœur")
                sagaRating != null && sagaRating > 0 -> L("Série notée %@", stars(sagaRating))
                else -> seriesName ?: ""
            }
            ReleaseSource.NARRATOR -> narrator?.let { L("%@ prête sa voix", it) } ?: ""
            ReleaseSource.AWAITED -> if (format == BookFormat.AUDIOBOOK) L("Dans votre liste d'envie · audio") else L("Dans votre liste d'envie")
        }

    companion object {
        fun stars(rating: Double): String {
            val filled = rating.roundToInt().coerceIn(0, 5)
            return "★".repeat(filled) + "☆".repeat(5 - filled)
        }
    }
}

/** A format as a filter pill names its books: "Livres audio", "Mangas". */
val BookFormat.pillLabel: String
    get() = when (this) {
        BookFormat.BOOK -> L("Livres")
        BookFormat.AUDIOBOOK -> L("Livres audio")
        BookFormat.BANDE_DESSINEE -> L("BD")
        BookFormat.COMIC -> L("Comics")
        BookFormat.MANGA -> L("Mangas")
    }
