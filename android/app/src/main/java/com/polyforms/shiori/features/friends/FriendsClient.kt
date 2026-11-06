package com.polyforms.shiori.features.friends

import com.polyforms.shiori.features.discover.AwaitedApi
import com.polyforms.shiori.features.discover.AwaitedEdition
import com.polyforms.shiori.features.discover.EditionOffer
import com.polyforms.shiori.features.discover.ReleaseFormat
import com.polyforms.shiori.features.wishlist.WishlistApi
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.SeriesState

/** Everything the friends' screens ask of the server: `live` goes through `FriendsApi`. */
interface FriendsClient {
    suspend fun friends(): List<Friend>
    suspend fun myShelf(): FriendProfile
    suspend fun profile(userId: String): FriendProfile?
    suspend fun libraryPage(friendId: String, status: ReadingStatus?, loved: Boolean, after: String?): Pair<List<FriendBook>, Boolean>
    suspend fun sagaPage(friendId: String, state: SeriesState?, loved: Boolean, after: String?): Pair<List<FriendSaga>, Boolean>
    suspend fun book(friendId: String, bookId: String): FriendBook?
    suspend fun audio(friendId: String, bookId: String): AudioAvailability?
    suspend fun addBook(friendId: String, bookId: String, status: CopiedStatus, format: BookFormat)
    suspend fun offer(friendId: String, bookId: String): EditionOffer?
    suspend fun awaitEdition(friendId: String, bookId: String, format: ReleaseFormat): AwaitedEdition
    suspend fun stopAwaiting(editionId: String)
    suspend fun invite(): FriendInvitation
    suspend fun accept(code: String): Friend
    suspend fun remove(userId: String)

    /** Onto the reader's wishlist: the server re-reads the friend's book. */
    suspend fun wish(friendId: String, bookId: String)

    companion object {
        val live: FriendsClient = object : FriendsClient {
            override suspend fun friends() = FriendsApi.friends()
            override suspend fun myShelf() = FriendsApi.myShelf()
            override suspend fun profile(userId: String) = FriendsApi.profile(userId)
            override suspend fun libraryPage(friendId: String, status: ReadingStatus?, loved: Boolean, after: String?) =
                FriendsApi.libraryPage(friendId, status, loved, after)
            override suspend fun sagaPage(friendId: String, state: SeriesState?, loved: Boolean, after: String?) =
                FriendsApi.sagaPage(friendId, state, loved, after)
            override suspend fun book(friendId: String, bookId: String) = FriendsApi.book(friendId, bookId)
            override suspend fun audio(friendId: String, bookId: String) = FriendsApi.audio(friendId, bookId)
            override suspend fun addBook(friendId: String, bookId: String, status: CopiedStatus, format: BookFormat) {
                FriendsApi.addBook(friendId, bookId, status, format)
            }
            override suspend fun offer(friendId: String, bookId: String) = AwaitedApi.offer(friendId, bookId)
            override suspend fun awaitEdition(friendId: String, bookId: String, format: ReleaseFormat) = AwaitedApi.awaitEdition(friendId, bookId, format)
            override suspend fun stopAwaiting(editionId: String) = AwaitedApi.stop(editionId)
            override suspend fun invite() = FriendsApi.invite()
            override suspend fun accept(code: String) = FriendsApi.accept(code)
            override suspend fun remove(userId: String) {
                FriendsApi.remove(userId)
            }
            override suspend fun wish(friendId: String, bookId: String) {
                WishlistApi.wish(friendId, bookId)
            }
        }
    }
}

/** Says on every shelf of the profile that the reader now holds the book. */
fun FriendProfile.markingOwned(bookId: String): FriendProfile {
    fun FriendBook.owned() = if (id == bookId) copy(inLibrary = true) else this
    return copy(
        reading = reading.map { it.owned() },
        pile = pile.map { it.owned() },
        favorites = favorites.map { it.owned() },
        lastFinished = lastFinished?.owned(),
        lastDropped = lastDropped?.owned(),
        lastAdded = lastAdded?.owned(),
    )
}
