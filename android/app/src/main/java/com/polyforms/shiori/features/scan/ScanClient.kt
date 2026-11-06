package com.polyforms.shiori.features.scan

import com.polyforms.shiori.features.book.BookApi
import com.polyforms.shiori.features.book.BookCorrection
import com.polyforms.shiori.features.book.BookDraft
import com.polyforms.shiori.features.book.BookVocabulary
import com.polyforms.shiori.features.discover.AwaitedApi
import com.polyforms.shiori.features.discover.ReleaseFormat
import com.polyforms.shiori.features.subscription.SubscriptionApi
import com.polyforms.shiori.features.wishlist.Wish
import com.polyforms.shiori.features.wishlist.WishlistApi
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookLanguage

/** What a scan asks of the server: reading a cover, a link or a title, and adding the book. */
interface ScanClient {
    suspend fun scan(jpeg: ByteArray): ScannedBook
    suspend fun lookUpLink(link: String): ScannedBook
    suspend fun lookUpTitle(title: String): ScannedBook
    suspend fun searchTitle(title: String): List<TitleCandidate>
    suspend fun add(draft: BookDraft): Book
    suspend fun update(id: String, correction: BookCorrection): Book
    suspend fun rate(id: String, stars: Double): Book
    suspend fun setFavorite(id: String, favorite: Boolean): Book
    suspend fun awaitableFormats(language: BookLanguage, format: BookFormat): List<ReleaseFormat>
    suspend fun vocabulary(): BookVocabulary
    suspend fun subgenres(): List<String>
    suspend fun detectShelf(jpeg: ByteArray): List<DetectedBook>
    suspend fun addDetected(book: DetectedBook): Book
    suspend fun remainingScans(): Int?
    suspend fun wish(draft: BookDraft)

    companion object {
        val live: ScanClient = object : ScanClient {
            override suspend fun scan(jpeg: ByteArray) = ScanApi.scan(jpeg)
            override suspend fun lookUpLink(link: String) = ScanApi.lookUpLink(link)
            override suspend fun lookUpTitle(title: String) = ScanApi.lookUpTitle(title)
            override suspend fun searchTitle(title: String) = ScanApi.searchTitle(title)
            override suspend fun add(draft: BookDraft) = BookApi.add(draft)
            override suspend fun update(id: String, correction: BookCorrection) = BookApi.update(id, correction)
            override suspend fun rate(id: String, stars: Double) = BookApi.rate(id, stars)
            override suspend fun setFavorite(id: String, favorite: Boolean) = BookApi.setFavorite(id, favorite)
            override suspend fun awaitableFormats(language: BookLanguage, format: BookFormat) = AwaitedApi.formats(language, format)
            override suspend fun vocabulary() = BookApi.vocabulary()
            override suspend fun subgenres() = BookApi.subgenres()
            override suspend fun detectShelf(jpeg: ByteArray) = ScanApi.detect(jpeg)
            override suspend fun addDetected(book: DetectedBook) = ScanApi.addDetected(book)
            override suspend fun remainingScans() = runCatching { SubscriptionApi.quota().totalRemaining }.getOrNull()
            override suspend fun wish(draft: BookDraft) {
                WishlistApi.wish(draft, Wish.Origin.SCAN)
            }
        }
    }
}
