package com.polyforms.shiori.features.discover

import com.polyforms.shiori.features.authors.asDomain
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
