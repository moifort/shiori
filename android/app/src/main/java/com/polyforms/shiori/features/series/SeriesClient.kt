package com.polyforms.shiori.features.series

import com.polyforms.shiori.features.book.BookAddition
import com.polyforms.shiori.features.book.BookApi
import com.polyforms.shiori.features.book.BookCorrection
import com.polyforms.shiori.features.book.BookDraft
import com.polyforms.shiori.features.discover.DiscoverApi
import com.polyforms.shiori.features.discover.SagaReleases
import com.polyforms.shiori.features.friends.FriendSaga
import com.polyforms.shiori.features.friends.FriendsApi
import com.polyforms.shiori.shared.AnalyticsEvent
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookSeries
import com.polyforms.shiori.shared.CursorPage
import com.polyforms.shiori.shared.FollowedSeries
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.SeriesOpinion

/** The friend whose copy of a saga a screen shows. */
data class SeriesFriend(val id: String, val name: String)

interface SeriesClient {
    suspend fun screen(id: String, proposal: SeriesProposal?): SeriesScreenData
    suspend fun catalogue(id: String, proposal: SeriesProposal?): BookSeries?
    suspend fun friendScreen(friendId: String, seriesId: String): Pair<BookSeries?, FriendSaga?>
    suspend fun releases(seriesId: String): SagaReleases
    suspend fun lookUpReleases(seriesId: String): SagaReleases
    suspend fun rate(seriesId: String, stars: Double): SeriesOpinion
    suspend fun removeRating(seriesId: String): SeriesOpinion
    suspend fun setFollowed(seriesId: String, followed: Boolean): SeriesOpinion
    suspend fun setFavorite(seriesId: String, favorite: Boolean): SeriesOpinion
    suspend fun declareVolumeCount(seriesId: String, count: Int): SeriesOpinion
    suspend fun delete(seriesId: String)
    suspend fun mergeCandidates(): List<FollowedSeries>
    suspend fun merge(seriesId: String, into: String)
    suspend fun updateBook(id: String, correction: BookCorrection): Book
    suspend fun setStatus(id: String, status: ReadingStatus): Book
    suspend fun addAudibleVolume(seriesId: String, volume: Int): Book
    suspend fun addBook(draft: BookDraft, lookUp: BookAddition.LookUp?): Book
    suspend fun subgenres(): List<String>
    suspend fun page(limit: Int, after: String?): CursorPage<FollowedSeries>
    suspend fun followedRow(seriesId: String): FollowedSeries?
    suspend fun correct(seriesId: String, correction: SeriesCorrection): BookSeries?

    companion object {
        val live: SeriesClient = object : SeriesClient {
            override suspend fun screen(id: String, proposal: SeriesProposal?) = SeriesApi.screen(id, proposal)
            override suspend fun catalogue(id: String, proposal: SeriesProposal?) = SeriesApi.catalogue(id, proposal)
            override suspend fun friendScreen(friendId: String, seriesId: String) = FriendsApi.sagaScreen(friendId, seriesId)
            override suspend fun releases(seriesId: String) = DiscoverApi.sagaReleases(seriesId)
            override suspend fun lookUpReleases(seriesId: String) = DiscoverApi.lookUpSaga(seriesId)
            override suspend fun rate(seriesId: String, stars: Double) = SeriesApi.rate(seriesId, stars)
            override suspend fun removeRating(seriesId: String) = SeriesApi.removeRating(seriesId)
            override suspend fun setFollowed(seriesId: String, followed: Boolean) = SeriesApi.setFollowed(seriesId, followed)
            override suspend fun setFavorite(seriesId: String, favorite: Boolean) = SeriesApi.setFavorite(seriesId, favorite)
            override suspend fun declareVolumeCount(seriesId: String, count: Int) = SeriesApi.declareVolumeCount(seriesId, count)
            override suspend fun delete(seriesId: String) {
                SeriesApi.delete(seriesId)
            }
            override suspend fun mergeCandidates() = SeriesApi.mergeCandidates()
            override suspend fun merge(seriesId: String, into: String) {
                SeriesApi.merge(seriesId, into)
            }
            override suspend fun updateBook(id: String, correction: BookCorrection) = BookApi.update(id, correction)
            override suspend fun setStatus(id: String, status: ReadingStatus) = BookApi.setStatus(id, status)
            override suspend fun addAudibleVolume(seriesId: String, volume: Int) = SeriesApi.addAudibleVolume(seriesId, volume)
            override suspend fun addBook(draft: BookDraft, lookUp: BookAddition.LookUp?) = BookAddition.add(draft, lookUp, AnalyticsEvent.BookSource.SERIES)
            override suspend fun subgenres() = BookApi.subgenres()
            override suspend fun page(limit: Int, after: String?) = SeriesApi.mySeriesPage(limit, after)
            override suspend fun followedRow(seriesId: String) = SeriesApi.followedSeries(seriesId)
            override suspend fun correct(seriesId: String, correction: SeriesCorrection) = SeriesApi.correct(seriesId, correction)
        }
    }
}
