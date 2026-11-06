@file:UseSerializers(InstantSerializer::class)

package com.polyforms.shiori.features.wishlist

import com.polyforms.shiori.features.book.BookDraft
import com.polyforms.shiori.features.discover.AwaitedEdition
import com.polyforms.shiori.features.discover.AwaitedState
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookLanguage
import com.polyforms.shiori.shared.InstantSerializer
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.SnapshotCache
import kotlinx.serialization.Serializable
import kotlinx.serialization.UseSerializers
import java.time.Instant

/** A book the reader wants, from a friend, a discovery, an award, an author or a scan. */
@Serializable
data class Wish(
    val id: String,
    val title: String,
    val authors: List<String>,
    val format: BookFormat,
    val language: BookLanguage?,
    val seriesName: String?,
    val volume: Int?,
    val coverURL: String?,
    val isbn13: String?,
    val origin: Origin,
    val originLabel: String?,
    val friendId: String?,
    val wishedAt: Instant,
) {
    enum class Origin { FRIEND, DISCOVERY, AWARD, AUTHOR, SCAN }

    val originCaption: String
        get() = when (origin) {
            Origin.FRIEND -> originLabel ?: L("Un ami")
            Origin.DISCOVERY -> L("Découverte")
            Origin.AWARD -> originLabel ?: L("Prix")
            Origin.AUTHOR -> L("Auteur")
            Origin.SCAN -> L("Scan")
        }

    val cover: Book get() = Book(id = "wish-$id", title = title, authors = authors, format = format, language = language, coverURL = coverURL, status = ReadingStatus.TO_READ)

    fun draft(status: ReadingStatus): BookDraft = BookDraft(
        title = title,
        authors = authors,
        format = format,
        media = if (format == BookFormat.AUDIOBOOK) emptyList() else BookDraft(title).media,
        language = language,
        isbn13 = isbn13,
        coverURL = coverURL,
        status = status,
    )
}

@Serializable
data class Wishlist(val wishes: List<Wish> = emptyList(), val awaited: List<AwaitedEdition> = emptyList()) {
    val isEmpty: Boolean get() = wishes.isEmpty() && awaited.isEmpty()
    val upcoming: List<AwaitedEdition> get() = awaited.filter { it.announcedDate != null }.sortedBy { it.date ?: "" }
    val released: List<AwaitedEdition> get() = awaited.filter { it.state == AwaitedState.AVAILABLE }
    val unannounced: List<AwaitedEdition> get() = awaited.filter { it.state != AwaitedState.AVAILABLE && it.announcedDate == null }
    val fromFriends: List<Wish> get() = wishes.filter { it.origin == Wish.Origin.FRIEND }
    val discovered: List<Wish> get() = wishes.filter { it.origin in setOf(Wish.Origin.DISCOVERY, Wish.Origin.AWARD, Wish.Origin.AUTHOR) }
    val scanned: List<Wish> get() = wishes.filter { it.origin == Wish.Origin.SCAN }
    val availableNow: List<Book> get() = released.map { it.cover } + wishes.map { it.cover }

    fun caption(book: Book): String = wishes.firstOrNull { it.cover.id == book.id }?.originCaption ?: L("Guetté")
    fun wish(book: Book): Wish? = wishes.firstOrNull { it.cover.id == book.id }
    fun edition(book: Book): AwaitedEdition? = awaited.firstOrNull { it.cover.id == book.id }

    companion object {
        val cache get() = SnapshotCache("wishlist", 1, serializer())
    }
}
