package com.polyforms.shiori.features.series

import com.apollographql.apollo.api.Optional
import com.polyforms.shiori.graphql.AddAudibleSeriesVolumeMutation
import com.polyforms.shiori.graphql.CorrectSeriesMutation
import com.polyforms.shiori.graphql.DeclareSeriesVolumeCountMutation
import com.polyforms.shiori.graphql.DeleteSeriesMutation
import com.polyforms.shiori.graphql.MergeCandidatesQuery
import com.polyforms.shiori.graphql.MergeSeriesMutation
import com.polyforms.shiori.graphql.MyFollowedSeriesQuery
import com.polyforms.shiori.graphql.MySeriesPageQuery
import com.polyforms.shiori.graphql.RateSeriesMutation
import com.polyforms.shiori.graphql.RemoveSeriesRatingMutation
import com.polyforms.shiori.graphql.SeriesCatalogueBuiltQuery
import com.polyforms.shiori.graphql.SeriesScreenQuery
import com.polyforms.shiori.graphql.SetSeriesFavoriteMutation
import com.polyforms.shiori.graphql.SetSeriesFollowedMutation
import com.polyforms.shiori.graphql.fragment.CatalogueSpine
import com.polyforms.shiori.graphql.fragment.DiscoveredVolumeFields
import com.polyforms.shiori.graphql.fragment.FollowedSeriesRow
import com.polyforms.shiori.graphql.fragment.FollowedVolume
import com.polyforms.shiori.graphql.fragment.SeriesCatalogue
import com.polyforms.shiori.graphql.type.ProposedSagaInput
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookSeries
import com.polyforms.shiori.shared.CursorPage
import com.polyforms.shiori.shared.DataChange
import com.polyforms.shiori.shared.DiscoveredVolume
import com.polyforms.shiori.shared.FollowedSeries
import com.polyforms.shiori.shared.GraphQLClient
import com.polyforms.shiori.shared.SeriesMembership
import com.polyforms.shiori.shared.SeriesOpinion
import com.polyforms.shiori.shared.SeriesStripItem
import com.polyforms.shiori.shared.Showcase
import com.polyforms.shiori.shared.ShowcaseData
import com.polyforms.shiori.shared.asBook
import com.polyforms.shiori.shared.asDomain
import com.polyforms.shiori.shared.asOpinion
import com.polyforms.shiori.shared.asVolume
import com.polyforms.shiori.shared.graphQL
import com.polyforms.shiori.shared.parseISO8601
import java.time.LocalDate

/** A saga's screen: its catalogue, the reader's opinion, the volumes they hold. */
data class SeriesScreenData(val series: BookSeries?, val opinion: SeriesOpinion?, val owned: List<Book>)

object SeriesApi {
    private fun proposed(proposal: SeriesProposal?): Optional<ProposedSagaInput?> =
        Optional.presentIfNotNull(proposal?.let { ProposedSagaInput(author = it.author, name = it.name) })

    suspend fun screen(id: String, proposal: SeriesProposal? = null): SeriesScreenData {
        if (Showcase.isOn) return ShowcaseData.seriesScreen(id).let { SeriesScreenData(it.series, null, it.owned) }
        val data = GraphQLClient.fetch(SeriesScreenQuery(id, proposed(proposal)))
        return SeriesScreenData(
            series = data.series?.seriesCatalogue?.asSeries,
            opinion = data.seriesOpinion?.seriesOpinionFields?.asOpinion,
            owned = data.mySeriesVolumes.map { row ->
                row.bookSummary.asBook.copy(
                    authorKeys = row.authorKeys,
                    publisher = row.publisher,
                    pageCount = row.pageCount,
                    durationMinutes = row.durationMinutes,
                    addedAt = parseISO8601(row.addedAt),
                    startedAt = parseISO8601(row.startedAt),
                    finishedAt = parseISO8601(row.finishedAt),
                )
            },
        )
    }

    suspend fun catalogue(id: String, proposal: SeriesProposal? = null): BookSeries? =
        GraphQLClient.fetch(SeriesCatalogueBuiltQuery(id, proposed(proposal))).series?.seriesCatalogue?.asSeries

    suspend fun correct(seriesId: String, correction: SeriesCorrection): BookSeries? {
        val description: Optional<String?> = when (val d = correction.description) {
            null -> Optional.Absent
            is com.polyforms.shiori.features.book.Change.Set -> Optional.present(d.value)
            com.polyforms.shiori.features.book.Change.Clear -> Optional.present(null)
        }
        val data = GraphQLClient.perform(
            CorrectSeriesMutation(
                seriesId = seriesId,
                name = Optional.presentIfNotNull(correction.name),
                format = Optional.presentIfNotNull(correction.format?.graphQL),
                description = description,
            ),
        )
        return data.correctSeries?.seriesCatalogue?.asSeries
    }

    suspend fun addAudibleVolume(seriesId: String, volume: Int): Book =
        GraphQLClient.perform(AddAudibleSeriesVolumeMutation(seriesId, volume), DataChange.SeriesChange(seriesId))
            .addAudibleSeriesVolume.bookDetail.asBook

    suspend fun mySeriesPage(limit: Int, after: String?): CursorPage<FollowedSeries> {
        if (Showcase.isOn) return CursorPage.of(ShowcaseLibraryRows.series, limit, after) { it.seriesId }
        val page = GraphQLClient.fetch(MySeriesPageQuery(Optional.present(limit), Optional.presentIfNotNull(after))).mySeriesPage
        return CursorPage(
            page.items.map { followedRow(it.followedSeriesRow, it.volumes.map { v -> v.followedVolume }, it.catalogue?.catalogueSpine, it.nextRelease?.discoveredVolumeFields) },
            page.hasMore,
            page.endCursor,
        )
    }

    suspend fun followedSeries(seriesId: String): FollowedSeries? {
        if (Showcase.isOn) return ShowcaseLibraryRows.series.firstOrNull { it.seriesId == seriesId }
        val item = GraphQLClient.fetch(MyFollowedSeriesQuery(seriesId)).myFollowedSeries ?: return null
        return followedRow(item.followedSeriesRow, item.volumes.map { it.followedVolume }, item.catalogue?.catalogueSpine, item.nextRelease?.discoveredVolumeFields)
    }

    /** A followed saga as the Series tab draws it: its strip laid over the catalogue's spine. */
    fun followedRow(
        row: FollowedSeriesRow,
        volumes: List<FollowedVolume>,
        catalogue: CatalogueSpine?,
        nextRelease: DiscoveredVolumeFields? = null,
    ): FollowedSeries {
        val base = row.asFollowed
        val books = volumes.map { it.asBook }
        return base.copy(
            announced = nextRelease?.asDomain,
            volumes = books,
            isCatalogued = catalogue != null,
            strip = SeriesStripItem.strip(
                owned = books,
                spine = catalogue?.spine?.map { it.volumeEntry.asVolume }.orEmpty(),
                currentYear = LocalDate.now().year,
                language = base.language,
                catalogedAt = catalogue?.let { parseISO8601(it.catalogedAt) },
            ),
        )
    }

    suspend fun delete(seriesId: String): Int = GraphQLClient.perform(DeleteSeriesMutation(seriesId), DataChange.SeriesChange(seriesId)).deleteSeries

    suspend fun mergeCandidates(): List<FollowedSeries> = GraphQLClient.fetch(MergeCandidatesQuery()).mySeries.map { it.followedSeriesRow.asFollowed }

    suspend fun merge(seriesId: String, into: String): Int = GraphQLClient.perform(MergeSeriesMutation(seriesId, into)).mergeSeries

    suspend fun rate(seriesId: String, stars: Double): SeriesOpinion =
        GraphQLClient.perform(RateSeriesMutation(seriesId, stars), DataChange.SeriesChange(seriesId)).rateSeries.seriesOpinionFields.asOpinion

    suspend fun removeRating(seriesId: String): SeriesOpinion =
        GraphQLClient.perform(RemoveSeriesRatingMutation(seriesId), DataChange.SeriesChange(seriesId)).removeSeriesRating.seriesOpinionFields.asOpinion

    suspend fun declareVolumeCount(seriesId: String, count: Int): SeriesOpinion =
        GraphQLClient.perform(DeclareSeriesVolumeCountMutation(seriesId, count), DataChange.SeriesChange(seriesId)).declareSeriesVolumeCount.seriesOpinionFields.asOpinion

    suspend fun setFollowed(seriesId: String, followed: Boolean): SeriesOpinion =
        GraphQLClient.perform(SetSeriesFollowedMutation(seriesId, followed), DataChange.SeriesChange(seriesId)).setSeriesFollowed.seriesOpinionFields.asOpinion

    suspend fun setFavorite(seriesId: String, favorite: Boolean): SeriesOpinion =
        GraphQLClient.perform(SetSeriesFavoriteMutation(seriesId, favorite), DataChange.SeriesChange(seriesId)).setSeriesFavorite.seriesOpinionFields.asOpinion
}

/** The showcase's followed sagas, filled with the showcase library. */
object ShowcaseLibraryRows {
    val series: List<FollowedSeries> = emptyList()
}

val SeriesCatalogue.asSeries: BookSeries
    get() = BookSeries(
        id = id,
        language = language?.asDomain,
        name = name,
        author = author,
        description = description,
        spine = spine.map { it.volumeEntry.asVolume },
        relatedWorks = relatedWorks.map { it.volumeEntry.asVolume },
        isProvisional = provisional,
        isAwaitingCatalogue = awaitingCatalogue,
        isAudio = audio,
        catalogedAt = parseISO8601(catalogedAt),
    )

val FollowedSeriesRow.asFollowed: FollowedSeries
    get() = FollowedSeries(
        seriesId = id,
        name = name,
        isAudio = audio,
        saga = saga,
        author = author,
        language = language?.asDomain,
        state = state?.asDomain,
        genre = genre?.asDomain,
        ownedCount = ownedCount,
        shelvedAt = parseISO8601(shelvedAt),
        opinion = opinion?.seriesOpinionFields?.asOpinion,
    )

val FollowedVolume.asBook: Book
    get() = Book(
        id = id,
        title = title,
        authors = emptyList(),
        format = format.asDomain,
        language = language?.asDomain,
        series = series?.let { SeriesMembership("", "", it.volume, it.kind.asDomain) },
        coverURL = coverUrl,
        status = status.asDomain,
    )

val DiscoveredVolumeFields.asDomain: DiscoveredVolume
    get() = DiscoveredVolume(number, title, date, isbn13, coverUrl, audibleUrl)

/** The first cover a saga's volumes have: its card's picture. */
val FollowedSeries.cardCoverURL: String? get() = volumes.firstOrNull { it.coverURL != null }?.coverURL
