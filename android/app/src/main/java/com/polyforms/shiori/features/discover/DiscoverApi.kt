package com.polyforms.shiori.features.discover

import com.polyforms.shiori.features.authors.asDomain
import com.polyforms.shiori.features.book.BookAddition
import com.polyforms.shiori.features.book.BookApi
import com.polyforms.shiori.features.book.BookDraft
import com.polyforms.shiori.features.wishlist.Wish
import com.polyforms.shiori.features.wishlist.WishlistApi
import com.polyforms.shiori.shared.Analytics
import com.polyforms.shiori.shared.AnalyticsEvent
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookLanguage
import com.polyforms.shiori.shared.SeriesStripItem
import com.polyforms.shiori.features.series.SeriesApi
import com.polyforms.shiori.features.series.asDomain
import com.polyforms.shiori.graphql.AuthorReleasesQuery
import com.polyforms.shiori.graphql.DiscoveryQuery
import com.polyforms.shiori.graphql.LookUpDiscoveryMutation
import com.polyforms.shiori.graphql.LookUpSagaReleasesMutation
import com.polyforms.shiori.graphql.SagaReleasesQuery
import com.polyforms.shiori.graphql.fragment.AuthorReleasesFields
import com.polyforms.shiori.graphql.fragment.DiscoveredWorkFields
import com.polyforms.shiori.graphql.fragment.DiscoveryFields
import com.polyforms.shiori.graphql.fragment.SagaReleasesFields
import com.polyforms.shiori.shared.DataChange
import com.polyforms.shiori.shared.GraphQLClient
import com.polyforms.shiori.shared.Showcase

object DiscoverApi {
    suspend fun discovery(format: ReleaseFormat): DiscoveryPage {
        if (Showcase.isOn) return DiscoveryPage(emptyList(), emptyList(), 0, 0)
        return GraphQLClient.fetch(DiscoveryQuery(format.graphQL)).discovery.discoveryFields.asDomain
    }

    suspend fun lookUp(format: ReleaseFormat): DiscoveryPage =
        GraphQLClient.perform(LookUpDiscoveryMutation(format.graphQL)).lookUpDiscovery.discoveryFields.asDomain

    suspend fun sagaReleases(seriesId: String): SagaReleases {
        if (Showcase.isOn) return SagaReleases(true, null)
        return GraphQLClient.fetch(SagaReleasesQuery(seriesId)).sagaReleases.sagaReleasesFields.asDomain
    }

    suspend fun authorReleases(key: String): Map<ReleaseFormat, AuthorReleases> {
        val data = GraphQLClient.fetch(AuthorReleasesQuery(key))
        return mapOf(ReleaseFormat.BOOK to data.book.authorReleasesFields.asDomain, ReleaseFormat.AUDIOBOOK to data.audiobook.authorReleasesFields.asDomain)
    }

    suspend fun lookUpSaga(seriesId: String): SagaReleases =
        GraphQLClient.perform(LookUpSagaReleasesMutation(seriesId), DataChange.SeriesChange(seriesId)).lookUpSagaReleases.sagaReleasesFields.asDomain
}

/**
 * Everything the release, award and suggestion pages ask of the server: `live` goes through the
 * domain's APIs, and a test builds the one it needs.
 */
interface DiscoverClient {
    suspend fun stopAwaiting(editionId: String)

    /** Awaits a book not in the library, and answers with the edition the server now watches. */
    suspend fun awaitEdition(draft: BookDraft, format: ReleaseFormat): AwaitedEdition
    suspend fun dismissSuggestion(id: String, reason: DismissalReason)

    /** The release a list showed, described for its page by the server. */
    suspend fun describe(item: ReleaseItem): Release

    /** A book put on the shelf from its page: the book's id. */
    suspend fun addSuggestion(draft: BookDraft): String

    /** Onto the wishlist, with where it was seen and what labels it: the wish's id. */
    suspend fun wish(draft: BookDraft, origin: Wish.Origin, label: String?): String

    /** A wish taken back. */
    suspend fun removeWish(wishId: String)

    /** A book put on the shelf by mistake from its page, off the shelf again. */
    suspend fun deleteBook(id: String)
    suspend fun reconsiderSuggestion(id: String)

    /** An award winner turned down, the novel in every format. */
    suspend fun dismissWinner(key: String)
    suspend fun reconsiderWinner(key: String)

    /** A saga's recording through the reader's Audible account: the book's id. */
    suspend fun addAudibleVolume(seriesId: String, volume: Int): String

    /** The volumes of a saga, held or lacking, for the row on a book to come's page. */
    suspend fun sagaVolumes(seriesId: String, language: BookLanguage?): List<SeriesStripItem>

    /** A saga's alerts on or off: the bell on its volume announced. */
    suspend fun setSagaFollowed(seriesId: String, followed: Boolean)

    /** The reader's own copy an edition is awaited of, for its saga. */
    suspend fun book(bookId: String): Book?

    companion object {
        val live: DiscoverClient = object : DiscoverClient {
            override suspend fun stopAwaiting(editionId: String) = AwaitedApi.stop(editionId)
            override suspend fun awaitEdition(draft: BookDraft, format: ReleaseFormat) = AwaitedApi.awaitScanned(draft, format)
            override suspend fun dismissSuggestion(id: String, reason: DismissalReason) = SuggestionsApi.dismiss(id, reason)
            override suspend fun describe(item: ReleaseItem) = ReleaseApi.describe(item)
            override suspend fun addSuggestion(draft: BookDraft) = BookAddition.add(draft, source = AnalyticsEvent.BookSource.DISCOVER).id
            override suspend fun wish(draft: BookDraft, origin: Wish.Origin, label: String?) = WishlistApi.wish(draft, origin, label).id
            override suspend fun removeWish(wishId: String) = WishlistApi.remove(wishId)
            override suspend fun deleteBook(id: String) = BookApi.delete(id)
            override suspend fun reconsiderSuggestion(id: String) = SuggestionsApi.reconsider(id)
            override suspend fun dismissWinner(key: String) = AwardsApi.dismiss(key)
            override suspend fun reconsiderWinner(key: String) = AwardsApi.reconsider(key)
            override suspend fun addAudibleVolume(seriesId: String, volume: Int): String {
                val book = SeriesApi.addAudibleVolume(seriesId, volume)
                Analytics.track(AnalyticsEvent.BookAdded(AnalyticsEvent.BookSource.DISCOVER))
                return book.id
            }
            override suspend fun sagaVolumes(seriesId: String, language: BookLanguage?) = BookApi.sagaVolumes(seriesId, language)
            override suspend fun setSagaFollowed(seriesId: String, followed: Boolean) {
                SeriesApi.setFollowed(seriesId, followed)
            }
            override suspend fun book(bookId: String) = BookApi.book(bookId)
        }
    }
}

/** What the saga screens asked last, kept for the session so a return does not ask again. */
object SagaReleasesCache {
    val entries = mutableMapOf<String, SagaReleases>()
}

val SagaReleasesFields.asDomain: SagaReleases get() = SagaReleases(watched, next?.discoveredVolumeFields?.asDomain)

val DiscoveredWorkFields.asDomain: DiscoveredWork get() = DiscoveredWork(title, date, isbn13, coverUrl, audibleUrl, seriesName, volume)

val AuthorReleasesFields.asDomain: AuthorReleases
    get() = AuthorReleases(next?.discoveredWorkFields?.asDomain, recent.map { it.discoveredWorkFields.asDomain }, awaited.map { it.awaitedEditionFields.asDomain })

val DiscoveryFields.asDomain: DiscoveryPage
    get() {
        val rows = sagas.map { row ->
            SagaDiscovery(
                series = SeriesApi.followedRow(row.series.followedSeriesRow, row.series.volumes.map { it.followedVolume }, row.series.catalogue?.catalogueSpine),
                releases = SagaReleases(true, row.next?.discoveredVolumeFields?.asDomain),
                missing = row.missing,
                recent = row.recent.map { it.discoveredVolumeFields.asDomain },
            )
        }
        val byId = rows.associateBy { it.id }
        return DiscoveryPage(
            rows = rows,
            authors = authors.map { row ->
                AuthorDiscovery(
                    author = row.author.followedAuthorRow.asDomain,
                    next = row.next?.discoveredWorkFields?.asDomain,
                    recent = row.recent.map { it.discoveredWorkFields.asDomain },
                    awaited = row.awaited.map { it.awaitedEditionFields.asDomain },
                    sagas = row.sagas.mapNotNull { byId[it.series.id] },
                )
            },
            unwatched = unwatched,
            followed = followed,
        )
    }
