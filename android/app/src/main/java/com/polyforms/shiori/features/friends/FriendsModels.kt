@file:UseSerializers(InstantSerializer::class)

package com.polyforms.shiori.features.friends

import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookGenre
import com.polyforms.shiori.shared.BookLanguage
import com.polyforms.shiori.shared.InstantSerializer
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.SeriesState
import com.polyforms.shiori.shared.account.AccountAvatar
import com.polyforms.shiori.shared.account.AvatarColor
import com.polyforms.shiori.shared.account.AvatarHero
import kotlinx.serialization.Serializable
import kotlinx.serialization.UseSerializers
import java.time.Instant
import java.time.temporal.ChronoUnit

@Serializable
data class Friend(
    val userId: String,
    val firstName: String?,
    val since: Instant,
    val bookCount: Int = 0,
    val favoriteCount: Int = 0,
    val readingCount: Int = 0,
    val toReadCount: Int = 0,
    val readThisYear: Int = 0,
    val recentActivity: List<RecentActivity> = emptyList(),
) {
    val id: String get() = userId
    val displayName: String get() = firstName ?: L("Un lecteur")
    val initials: String get() = displayName.split(" ").take(2).mapNotNull { it.firstOrNull() }.joinToString("").uppercase()

    companion object {
        fun seenByFriends(shelf: FriendProfile) = Friend(
            userId = shelf.userId,
            firstName = shelf.firstName,
            since = Instant.now(),
            bookCount = shelf.bookCount,
            favoriteCount = shelf.favorites.size + shelf.favoriteSagas.size,
            readingCount = shelf.reading.size,
            toReadCount = shelf.pile.size,
            readThisYear = shelf.readThisYear,
            recentActivity = shelf.recentActivity(),
        )
    }
}

/** A friend's book, as their shared shelf shows it. */
@Serializable
data class FriendBook(
    val book: Book,
    val inLibrary: Boolean,
    val favoritedAt: Instant? = null,
    val lastActivityAt: Instant? = null,
    val ownerAvatarHero: String? = null,
    val ownerAvatarColor: String? = null,
) {
    val id: String get() = book.id

    val ownerAvatar: AccountAvatar
        get() {
            ownerAvatarHero?.let(AvatarHero::ofGraphQL)?.let { return AccountAvatar.Hero(it) }
            ownerAvatarColor?.let { c -> AvatarColor.entries.firstOrNull { it.name == c.uppercase() } }?.let { return AccountAvatar.Tinted(it) }
            return AccountAvatar.Initials
        }
}

enum class AudioAvailability { AVAILABLE, UNAVAILABLE, UNKNOWN }

enum class CopiedStatus { TO_READ, READ }

@Serializable
data class FriendSaga(
    val id: String,
    val seriesId: String,
    val name: String,
    val isAudio: Boolean = false,
    val author: String?,
    val language: BookLanguage?,
    val ownedCount: Int,
    val favorite: Boolean,
    val favoritedAt: Instant? = null,
    val rating: Double? = null,
    val genre: BookGenre?,
    val subgenre: String?,
    val volumes: List<Book> = emptyList(),
    val lastActivityAt: Instant? = null,
    val inLibrary: Boolean = false,
    val shelvedAt: Instant? = null,
    val state: SeriesState? = null,
)

@Serializable
data class FriendProfile(
    val userId: String,
    val firstName: String?,
    val reading: List<FriendBook>,
    val pile: List<FriendBook>,
    val favorites: List<FriendBook>,
    val sagas: List<FriendSaga>,
    val lastFinished: FriendBook? = null,
    val lastDropped: FriendBook? = null,
    val lastAdded: FriendBook? = null,
    val bookCount: Int = 0,
    val readThisYear: Int = 0,
) {
    val favoriteSagas: List<FriendSaga>
        get() {
            val hearted = sagas.filter { it.favorite }
            return hearted.filter { it.favoritedAt != null }.sortedByDescending { it.favoritedAt } + hearted.filter { it.favoritedAt == null }
        }

    val favoriteSagasByShelf: List<FriendSaga>
        get() = favoriteSagas.sortedWith(compareByDescending<FriendSaga> { it.shelvedAt ?: Instant.MIN }.thenBy { it.name })

    val favoritesByShelf: List<FriendBook>
        get() = favorites.sortedWith(compareByDescending<FriendBook> { it.book.shelvedAt ?: Instant.MIN }.thenBy { it.book.title })

    fun recentActivity(now: Instant = Instant.now()): List<RecentActivity> {
        val reading = reading.firstOrNull()?.let { e -> e.lastActivityAt?.let { RecentActivity(RecentActivity.Kind.READING, e, it) } }
        val finished = lastFinished?.let { e -> e.book.finishedAt?.let { RecentActivity(RecentActivity.Kind.FINISHED, e, it) } }
        val dropped = lastDropped?.let { e -> e.lastActivityAt?.let { RecentActivity(RecentActivity.Kind.DROPPED, e, it) } }
        val added = lastAdded?.let { e -> e.book.addedAt?.let { RecentActivity(RecentActivity.Kind.ADDED, e, it) } }
        val heart = favorites.mapNotNull { e -> e.favoritedAt?.let { RecentActivity(RecentActivity.Kind.HEARTED, e, it) } }.maxByOrNull { it.date }
        return listOfNotNull(reading, finished, heart, added, dropped).filter { it.isRecent(now) }
    }

    val displayName: String get() = firstName ?: L("Un lecteur")

    val isEmpty: Boolean get() = reading.isEmpty() && pile.isEmpty() && favorites.isEmpty() && sagas.isEmpty() && bookCount == 0
}

/** What a friend did last with a book. */
@Serializable
data class RecentActivity(val kind: Kind, val book: FriendBook, val date: Instant) {
    enum class Kind { READING, FINISHED, DROPPED, HEARTED, ADDED }

    val id: String get() = "${kind.name.lowercase()}-${book.id}"

    fun isRecent(now: Instant = Instant.now()): Boolean = kind == Kind.HEARTED || date >= now.minus(30, ChronoUnit.DAYS)
}

data class FriendInvitation(val code: String, val expiresAt: Instant) {
    val url: String get() = InvitationLink.url(code)
}

/** The links an invitation travels as: `https://<server>/invite/CODE`, or `shiori://invite/CODE`. */
object InvitationLink {
    const val HOST = "shiori-server-hvrhl6ox5q-ey.a.run.app"
    const val SCHEME = "shiori"
    private const val PATH = "invite"

    fun url(code: String) = "https://$HOST/$PATH/$code"

    fun code(url: android.net.Uri): String? {
        val segments = url.pathSegments
        if (url.scheme == SCHEME) {
            if (url.host != PATH) return null
            return segments.firstOrNull()?.let(::normalized)
        }
        if (url.host != HOST || segments.size != 2 || segments[0] != PATH) return null
        return normalized(segments[1])
    }

    private fun normalized(code: String): String? {
        val upper = code.uppercase()
        return if (upper.length == 8 && upper.all { it.isLetterOrDigit() }) upper else null
    }
}

/** Who among the reader's friends loved something. */
@Serializable
data class FriendLovers(val friends: List<Lover>, val lovedByMany: Boolean) {
    @Serializable
    data class Lover(val userId: String, val firstName: String?) {
        val displayName: String get() = firstName ?: L("Un lecteur")
    }

    val first: Lover? get() = friends.firstOrNull()

    val caption: String
        get() {
            val first = first ?: return ""
            return when (friends.size) {
                1 -> first.displayName
                2 -> L("%@ et %@", first.displayName, friends[1].displayName)
                else -> "${first.displayName} +${friends.size - 1}"
            }
        }
}

@Serializable
data class LovedBook(val book: FriendBook, val lovers: FriendLovers) {
    val id: String get() = book.id
}

@Serializable
data class LovedSaga(val saga: FriendSaga, val lovers: FriendLovers) {
    val id: String get() = saga.id
}

@Serializable
data class LovedAuthor(val key: String, val name: String, val portraitURL: String?, val lovers: FriendLovers) {
    val id: String get() = key
}

/** "Coups de cœur de vos amis": what friends hearted and the reader holds in no format. */
@Serializable
data class FriendPicks(val books: List<LovedBook> = emptyList(), val sagas: List<LovedSaga> = emptyList(), val authors: List<LovedAuthor> = emptyList())
