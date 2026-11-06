package com.polyforms.shiori.features.home

import com.polyforms.shiori.features.book.BookAddition
import com.polyforms.shiori.features.book.BookApi
import com.polyforms.shiori.features.book.BookDraft
import com.polyforms.shiori.features.discover.AwaitedApi
import com.polyforms.shiori.features.discover.AwaitedEdition
import com.polyforms.shiori.features.discover.DiscoverApi
import com.polyforms.shiori.features.discover.DiscoveryPage
import com.polyforms.shiori.features.discover.DismissalReason
import com.polyforms.shiori.features.discover.MonthlyDiscoveries
import com.polyforms.shiori.features.discover.ReleaseFormat
import com.polyforms.shiori.features.discover.SuggestionsApi
import com.polyforms.shiori.features.wishlist.Wish
import com.polyforms.shiori.features.wishlist.WishlistApi
import com.polyforms.shiori.shared.AnalyticsEvent
import com.polyforms.shiori.shared.ReadingStatus

/** What the Home asks of the server. */
interface HomeClient {
    suspend fun dashboard(): Dashboard
    suspend fun discoveries(): MonthlyDiscoveries
    suspend fun lookUpDiscoveries(): MonthlyDiscoveries
    suspend fun discovery(format: ReleaseFormat): DiscoveryPage
    suspend fun awaited(format: ReleaseFormat): List<AwaitedEdition>
    suspend fun dismissSuggestion(id: String, reason: DismissalReason)
    suspend fun stopAwaiting(editionId: String)
    suspend fun reconsiderSuggestion(id: String)
    suspend fun genreInsights(): GenreInsights
    suspend fun addBook(draft: BookDraft): String
    suspend fun wish(draft: BookDraft)
    suspend fun deleteBook(id: String)
    suspend fun awaitEdition(draft: BookDraft, format: ReleaseFormat)
    suspend fun finish(bookId: String)
    suspend fun recordPage(bookId: String, page: Int?, status: ReadingStatus?)
    suspend fun rate(bookId: String, stars: Double)

    companion object {
        val live: HomeClient = object : HomeClient {
            override suspend fun dashboard() = HomeApi.dashboard()
            override suspend fun discoveries() = SuggestionsApi.monthly(ReleaseFormat.BOOK, lookUp = false)
            override suspend fun lookUpDiscoveries() = SuggestionsApi.monthly(ReleaseFormat.BOOK, lookUp = true)
            override suspend fun discovery(format: ReleaseFormat) = DiscoverApi.discovery(format)
            override suspend fun awaited(format: ReleaseFormat) = AwaitedApi.awaited(format)
            override suspend fun dismissSuggestion(id: String, reason: DismissalReason) = SuggestionsApi.dismiss(id, reason)
            override suspend fun stopAwaiting(editionId: String) = AwaitedApi.stop(editionId)
            override suspend fun reconsiderSuggestion(id: String) = SuggestionsApi.reconsider(id)
            override suspend fun genreInsights() = HomeApi.genreInsights()
            override suspend fun addBook(draft: BookDraft) = BookAddition.add(draft, source = AnalyticsEvent.BookSource.DISCOVER).id
            override suspend fun wish(draft: BookDraft) {
                WishlistApi.wish(draft, Wish.Origin.DISCOVERY)
            }
            override suspend fun deleteBook(id: String) = BookApi.delete(id)
            override suspend fun awaitEdition(draft: BookDraft, format: ReleaseFormat) {
                AwaitedApi.awaitScanned(draft, format)
            }
            override suspend fun finish(bookId: String) {
                BookApi.setStatus(bookId, ReadingStatus.READ)
            }
            override suspend fun recordPage(bookId: String, page: Int?, status: ReadingStatus?) {
                if (page != null) BookApi.recordPage(bookId, page)
                if (status != null) BookApi.setStatus(bookId, status)
            }
            override suspend fun rate(bookId: String, stars: Double) {
                BookApi.rate(bookId, stars)
            }
        }
    }
}
