package com.polyforms.shiori.features.news

import com.polyforms.shiori.features.book.BookAddition
import com.polyforms.shiori.features.book.BookApi
import com.polyforms.shiori.features.book.BookDraft
import com.polyforms.shiori.features.discover.AwardSection
import com.polyforms.shiori.features.discover.AwardsApi
import com.polyforms.shiori.features.discover.AwaitedApi
import com.polyforms.shiori.features.discover.DismissalReason
import com.polyforms.shiori.features.discover.ReleaseFormat
import com.polyforms.shiori.features.discover.Suggestion
import com.polyforms.shiori.features.discover.SuggestionsApi
import com.polyforms.shiori.features.friends.CopiedStatus
import com.polyforms.shiori.features.friends.FriendsApi
import com.polyforms.shiori.features.settings.NotificationsApi
import com.polyforms.shiori.features.wishlist.Wish
import com.polyforms.shiori.features.wishlist.WishlistApi
import com.polyforms.shiori.shared.AnalyticsEvent
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.CursorPage
import com.polyforms.shiori.shared.NotificationAuthorization
import com.polyforms.shiori.shared.PushRegistrar

/**
 * Everything the Actualités tab asks of the server: `live` goes through the domain's APIs and the
 * existing add-a-book use cases, `preview` answers from the fixtures, and a test builds the one
 * it needs inline. The writes answer the id of what they made, which a second tap takes back.
 */
interface NewsClient {
    suspend fun feed(after: String?, limit: Int): CursorPage<FeedEvent>
    suspend fun upcoming(): List<UpcomingRelease>

    /** What came out since the start of the year, which "Sorti" draws from. */
    suspend fun yearReleases(): List<UpcomingRelease>
    suspend fun narratorNews(): List<NarratorNews>

    /** A friend's book onto the pile or among the books read; answers the new book's id. */
    suspend fun addFriendBook(friendId: String, bookId: String, status: CopiedStatus, format: BookFormat): String

    /** A friend's book onto the wish list; answers the wish's id. */
    suspend fun wishFriendBook(friendId: String, bookId: String): String

    /** The friend's book's edition awaited in the app's language; answers the edition's id. */
    suspend fun awaitFriendBook(friendId: String, bookId: String, format: ReleaseFormat): String
    suspend fun addReleased(draft: BookDraft): String
    suspend fun wishReleased(draft: BookDraft): String
    suspend fun awaitReleased(draft: BookDraft, format: ReleaseFormat): String

    /** Whether nothing can reach the reader: the bell is struck through. */
    suspend fun alertsSilenced(): Boolean

    /** The prizes' winners in print. */
    suspend fun awards(): List<AwardSection> = emptyList()

    /** The month's discoveries already chosen: read, never asked for. */
    suspend fun discoveries(): List<Suggestion> = emptyList()

    /**
     * The first page and every section beside it in one request. Null, or a field in error, and
     * each section is asked alone.
     */
    val opening: (suspend (limit: Int) -> NewsOpening)? get() = null

    /** What the wish list rail shows, asked alone when the opening fails. */
    suspend fun wishlistReleases(): List<UpcomingRelease> = emptyList()

    /** A discovery or a prize onto the wish list. */
    suspend fun wishDiscovery(draft: BookDraft, origin: Wish.Origin): String = ""

    /** A wish taken back, from a second tap on the wished "Envies". */
    suspend fun removeWish(wishId: String) {}

    /** An awaited edition of the wish list's rail no longer awaited. */
    suspend fun stopAwaiting(editionId: String) {}

    /** "Pas intéressé" on the month's discovery. */
    suspend fun dismissSuggestion(id: String) {}

    /** "Pas intéressé" on a prize's winner. */
    suspend fun dismissWinner(key: String) {}

    /** The eye pressed again on a discovery, or its greyed "+ Ajouter". */
    suspend fun reconsiderSuggestion(id: String) {}
    suspend fun reconsiderWinner(key: String) {}

    /** A book taken from a card, its "À lire" or "Lu" capsule pressed. */
    suspend fun deleteBook(id: String) {}

    companion object {
        val live: NewsClient = object : NewsClient {
            override suspend fun feed(after: String?, limit: Int) = NewsApi.feed(after, limit)
            override suspend fun upcoming() = NewsApi.upcoming()
            override suspend fun yearReleases() = NewsApi.yearReleases()
            override suspend fun narratorNews() = NewsApi.narratorNews()
            override suspend fun addFriendBook(friendId: String, bookId: String, status: CopiedStatus, format: BookFormat) =
                FriendsApi.addBook(friendId, bookId, status, format)
            override suspend fun wishFriendBook(friendId: String, bookId: String) = WishlistApi.wish(friendId, bookId).id
            override suspend fun awaitFriendBook(friendId: String, bookId: String, format: ReleaseFormat) =
                AwaitedApi.awaitEdition(friendId, bookId, format).id
            override suspend fun addReleased(draft: BookDraft) = BookAddition.add(draft, source = AnalyticsEvent.BookSource.DISCOVER).id
            override suspend fun wishReleased(draft: BookDraft) = WishlistApi.wish(draft, Wish.Origin.DISCOVERY).id
            override suspend fun awaitReleased(draft: BookDraft, format: ReleaseFormat) = AwaitedApi.awaitScanned(draft, format).id
            override suspend fun alertsSilenced(): Boolean {
                val denied = PushRegistrar.authorization() == NotificationAuthorization.DENIED
                val settings = runCatching { NotificationsApi.settings() }.getOrNull()
                return denied || settings?.enabled?.isEmpty() == true
            }
            override suspend fun awards() = AwardsApi.sections(ReleaseFormat.BOOK)
            override suspend fun discoveries() = SuggestionsApi.monthly(ReleaseFormat.BOOK, lookUp = false).suggestions
            override val opening: (suspend (Int) -> NewsOpening) = { NewsApi.opening(it) }
            override suspend fun wishlistReleases() = NewsApi.wishlistReleases()
            override suspend fun wishDiscovery(draft: BookDraft, origin: Wish.Origin) = WishlistApi.wish(draft, origin).id
            override suspend fun removeWish(wishId: String) = WishlistApi.remove(wishId)
            override suspend fun stopAwaiting(editionId: String) = AwaitedApi.stop(editionId)
            override suspend fun dismissSuggestion(id: String) = SuggestionsApi.dismiss(id, DismissalReason.NOT_INTERESTED)
            override suspend fun dismissWinner(key: String) = AwardsApi.dismiss(key)
            override suspend fun reconsiderSuggestion(id: String) = SuggestionsApi.reconsider(id)
            override suspend fun reconsiderWinner(key: String) = AwardsApi.reconsider(key)
            override suspend fun deleteBook(id: String) = BookApi.delete(id)
        }

        val preview: NewsClient = object : NewsClient {
            override suspend fun feed(after: String?, limit: Int) = CursorPage(NewsFixtures.events, false, null)
            override suspend fun upcoming() = NewsFixtures.upcoming
            override suspend fun yearReleases() = NewsFixtures.released
            override suspend fun narratorNews() = listOf(NewsFixtures.narrator)
            override suspend fun addFriendBook(friendId: String, bookId: String, status: CopiedStatus, format: BookFormat) = "preview-book"
            override suspend fun wishFriendBook(friendId: String, bookId: String) = "preview-wish"
            override suspend fun awaitFriendBook(friendId: String, bookId: String, format: ReleaseFormat) = "preview-edition"
            override suspend fun addReleased(draft: BookDraft) = "preview-book"
            override suspend fun wishReleased(draft: BookDraft) = "preview-wish"
            override suspend fun awaitReleased(draft: BookDraft, format: ReleaseFormat) = "preview-edition"
            override suspend fun alertsSilenced() = false
            override suspend fun awards() = NewsFixtures.awards
            override suspend fun discoveries() = NewsFixtures.suggestions
            override suspend fun wishlistReleases() = NewsFixtures.wishlist
        }
    }
}
