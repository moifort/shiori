package com.polyforms.shiori.features.friends

import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.ReadingStatus
import java.time.Instant
import java.time.temporal.ChronoUnit

/**
 * The Amis tab's preview data, as iOS's `FriendsFixtures`: four friends with their avatars, and
 * their books as the rails draw them, every friend together.
 */
object FriendsFixtures {
    private fun ago(days: Long) = Instant.now().minus(days, ChronoUnit.DAYS)

    val friends = listOf(
        Friend("marc", "Marc", ago(300), avatarHero = "KVOTHE"),
        Friend("sophie", "Sophie", ago(200), avatarHero = "ALICE"),
        Friend("lea", "Léa", ago(90), avatarHero = "KATNISS"),
        Friend("camille", "Camille", ago(20)),
    )

    private fun entry(friend: Friend, book: Book, days: Long = 2) =
        FriendsShelfEntry(friend.userId, friend.firstName, FriendBook(book, inLibrary = false, lastActivityAt = ago(days), ownerAvatarHero = friend.avatarHero))

    val shelf: FriendsShelf = run {
        val (marc, sophie, lea, camille) = friends
        val reading = DebugFixtures.reading
        val toRead = DebugFixtures.toRead
        FriendsShelf(
            reading = listOf(entry(sophie, reading[0], 1), entry(marc, reading[1], 2), entry(camille, reading[2], 3), entry(lea, toRead[2], 4)),
            favorites = listOf(
                entry(lea, toRead[4].copy(status = ReadingStatus.READ, favorite = true, finishedAt = ago(6))),
                entry(marc, toRead[3].copy(status = ReadingStatus.READ, favorite = true, finishedAt = ago(12))),
            ),
            finished = listOf(
                entry(sophie, toRead[1].copy(status = ReadingStatus.READ, finishedAt = ago(3), rating = 4.0)),
                entry(camille, toRead[4].copy(id = "t5c", status = ReadingStatus.READ, finishedAt = ago(8), rating = 5.0)),
            ),
            pile = listOf(entry(marc, toRead[0], 1), entry(lea, toRead[1].copy(id = "t2l"), 5), entry(sophie, toRead[2].copy(id = "t3s"), 9)),
        )
    }

    val invitation = FriendInvitation("AB12CD34", ago(-7))

    /** A friend's whole library, as their "Livres" pages it. */
    val library: List<FriendBook>
        get() = (shelf.reading + shelf.favorites + shelf.finished + shelf.pile).map { it.book }.distinctBy { it.id }
            // Newest first on the day each book was shelved, as the server pages it.
            .sortedByDescending { it.book.shelvedAt }

    /** A friend's sagas: each book of a series, a saga of its own. */
    val sagas: List<FriendSaga>
        get() = library.mapNotNull { entry ->
            val series = entry.book.series ?: return@mapNotNull null
            FriendSaga(
                id = series.id, seriesId = series.id, name = series.name, isAudio = entry.book.format == com.polyforms.shiori.shared.BookFormat.AUDIOBOOK,
                author = entry.book.authors.firstOrNull(), language = entry.book.language, ownedCount = 1, favorite = entry.book.favorite,
                genre = entry.book.genre, subgenre = null, volumes = listOf(entry.book), shelvedAt = entry.book.shelvedAt,
            )
        }.distinctBy { it.id }

    /** Answers from the fixtures, at once, and accepts every write: the debug previews' client. */
    val client: FriendsClient = object : FriendsClient {
        override suspend fun friends() = FriendsFixtures.friends
        override suspend fun myShelf() = DebugFixtures.myShelf
        override suspend fun libraryPage(friendId: String, status: ReadingStatus?, format: com.polyforms.shiori.shared.BookFormat?, after: String?) =
            library.filter { (status == null || it.book.status == status) && (format == null || it.book.format == format) } to false
        override suspend fun sagaPage(friendId: String, state: com.polyforms.shiori.shared.SeriesState?, loved: Boolean, after: String?) = sagas to false
        override suspend fun book(friendId: String, bookId: String) = library.firstOrNull { it.id == bookId }
        override suspend fun audio(friendId: String, bookId: String) = AudioAvailability.AVAILABLE
        override suspend fun addBook(friendId: String, bookId: String, status: CopiedStatus, format: com.polyforms.shiori.shared.BookFormat) = Unit
        override suspend fun offer(friendId: String, bookId: String) = com.polyforms.shiori.features.discover.EditionOffer()
        override suspend fun awaitEdition(friendId: String, bookId: String, format: com.polyforms.shiori.features.discover.ReleaseFormat) =
            com.polyforms.shiori.features.discover.AwaitedEdition.pending(format, library.first().book)
        override suspend fun stopAwaiting(editionId: String) = Unit
        override suspend fun invite() = invitation
        override suspend fun accept(code: String) = friends[1]
        override suspend fun remove(userId: String) = Unit
        override suspend fun wish(friendId: String, bookId: String) = "wish"
        override suspend fun removeWish(wishId: String) = Unit
        override suspend fun friendsShelf(friendIds: List<String>) = shelf.narrowed(friendIds)
    }
}
