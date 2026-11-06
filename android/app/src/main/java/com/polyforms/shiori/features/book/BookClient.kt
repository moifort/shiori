package com.polyforms.shiori.features.book

import com.polyforms.shiori.features.discover.AwaitedApi
import com.polyforms.shiori.features.discover.AwaitedEdition
import com.polyforms.shiori.features.discover.EditionOffer
import com.polyforms.shiori.features.discover.ReleaseFormat
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookLanguage
import com.polyforms.shiori.shared.BookRecommendation
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.SeriesStripItem

/** What the book page asks the server, as functions a preview or a test can stand in for. */
interface BookClient {
    suspend fun book(id: String): Book?
    suspend fun add(draft: BookDraft): Book
    suspend fun setStatus(id: String, status: ReadingStatus): Book
    suspend fun recordPage(id: String, page: Int): Book
    suspend fun rate(id: String, stars: Double): Book
    suspend fun save(id: String, correction: BookCorrection, rating: RatingChange?): Book?
    suspend fun coverChoices(id: String): List<CoverChoice>
    suspend fun chooseCover(id: String, url: String?): Book
    suspend fun describe(id: String): Book
    suspend fun setFavorite(id: String, favorite: Boolean): Book
    suspend fun setRecommendation(id: String, recommendation: BookRecommendation?): Book
    suspend fun setNote(id: String, note: String?): Book
    suspend fun setHidden(id: String, hidden: Boolean): Book
    suspend fun delete(id: String)
    suspend fun vocabulary(): BookVocabulary
    suspend fun subgenres(): List<String>
    suspend fun offer(bookId: String): EditionOffer?
    suspend fun awaitEdition(bookId: String, format: ReleaseFormat): AwaitedEdition
    suspend fun stopAwaiting(editionId: String)
    suspend fun sagaVolumes(seriesId: String, language: BookLanguage?): List<SeriesStripItem>

    companion object {
        val live: BookClient = object : BookClient {
            override suspend fun book(id: String) = BookApi.book(id)
            override suspend fun add(draft: BookDraft) = BookApi.add(draft)
            override suspend fun setStatus(id: String, status: ReadingStatus) = BookApi.setStatus(id, status)
            override suspend fun recordPage(id: String, page: Int) = BookApi.recordPage(id, page)
            override suspend fun rate(id: String, stars: Double) = BookApi.rate(id, stars)
            override suspend fun save(id: String, correction: BookCorrection, rating: RatingChange?) = BookApi.save(id, correction, rating)
            override suspend fun coverChoices(id: String) = BookApi.coverChoices(id)
            override suspend fun chooseCover(id: String, url: String?) = BookApi.chooseCover(id, url)
            override suspend fun describe(id: String) = BookApi.describe(id)
            override suspend fun setFavorite(id: String, favorite: Boolean) = BookApi.setFavorite(id, favorite)
            override suspend fun setRecommendation(id: String, recommendation: BookRecommendation?) = BookApi.setRecommendation(id, recommendation)
            override suspend fun setNote(id: String, note: String?) = BookApi.setNote(id, note)
            override suspend fun setHidden(id: String, hidden: Boolean) = BookApi.setHidden(id, hidden)
            override suspend fun delete(id: String) = BookApi.delete(id)
            override suspend fun vocabulary() = BookApi.vocabulary()
            override suspend fun subgenres() = BookApi.subgenres()
            override suspend fun offer(bookId: String) = AwaitedApi.offer(bookId)
            override suspend fun awaitEdition(bookId: String, format: ReleaseFormat) = AwaitedApi.awaitEdition(bookId, format)
            override suspend fun stopAwaiting(editionId: String) = AwaitedApi.stop(editionId)
            override suspend fun sagaVolumes(seriesId: String, language: BookLanguage?) = BookApi.sagaVolumes(seriesId, language)
        }
    }
}
