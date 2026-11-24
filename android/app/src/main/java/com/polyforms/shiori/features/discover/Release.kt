package com.polyforms.shiori.features.discover

import com.polyforms.shiori.features.book.CoverChoice
import com.polyforms.shiori.features.book.coverChoiceOf
import com.polyforms.shiori.graphql.ChooseReleaseCoverMutation
import com.polyforms.shiori.graphql.DescribeReleaseOfMutation
import com.polyforms.shiori.graphql.ReleaseCoverChoicesQuery
import com.polyforms.shiori.graphql.fragment.ReleaseFields
import com.polyforms.shiori.graphql.type.AwardWinnerReleaseInput
import com.polyforms.shiori.graphql.type.ReleaseItemInput
import com.polyforms.shiori.graphql.type.SagaVolumeReleaseInput
import com.polyforms.shiori.graphql.type.SuggestionReleaseInput
import com.polyforms.shiori.graphql.type.AwaitedState as GAwaitedState
import com.polyforms.shiori.graphql.type.ReleaseFormat as GReleaseFormat
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookGenre
import com.polyforms.shiori.shared.BookLanguage
import com.polyforms.shiori.shared.BookMedium
import com.polyforms.shiori.shared.GraphQLClient
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.SeriesMembership
import com.polyforms.shiori.shared.VolumeKind
import com.polyforms.shiori.shared.asDomain
import com.apollographql.apollo.api.Optional
import kotlinx.serialization.Serializable

/**
 * A book the reader does not hold — an edition awaited, an award winner, a discovery, a saga's
 * volume — as every list and its page draw it. One record, built on the server from what the
 * web found of the edition and what its page described: a tile and the page it opens read this,
 * and nothing is merged on the device.
 */
@Serializable
data class Release(
    /** The same book, format and edition, whoever shows it. */
    val key: String,
    /** Its title as shown: the edition's once found, else the original's. */
    val title: String,
    val originalTitle: String = title,
    val authors: List<String>,
    /** What the book is: a novel, a manga, a recording. */
    val format: BookFormat,
    val releaseFormat: ReleaseFormat,
    /** The language of the book shown: the original's until the edition is found. */
    val language: BookLanguage? = null,
    val originalLanguage: BookLanguage? = null,
    val state: AwaitedState,
    /** Whether the web was ever searched for it. */
    val watched: Boolean = true,
    /** `YYYY`, `YYYY-MM` or `YYYY-MM-DD`. Null until found. */
    val date: String? = null,
    val isbn13: String? = null,
    val coverURL: String? = null,
    /** Where to get it: the recording on Audible, the printed edition on Amazon. */
    val storeURL: String? = null,
    /** Its saga, when the server knows which: a volume announced. */
    val series: SeriesMembership? = null,
    val publisher: String? = null,
    val firstPublishedIn: Int? = null,
    val synopsis: String? = null,
    val genre: BookGenre? = null,
    val subgenres: List<String> = emptyList(),
    val pageCount: Int? = null,
    val narrators: List<String> = emptyList(),
    val durationMinutes: Int? = null,
    /** Whether its page's description is kept and fresh; false, opening its page asks for it. */
    val described: Boolean = false,
) {
    /** Drawn as the shelves draw a book, on its tile and on its page alike. A recording says no medium. */
    fun book(id: String): Book = Book(
        id = id,
        title = title,
        authors = authors,
        format = format,
        media = if (format == BookFormat.AUDIOBOOK) emptyList() else listOf(BookMedium.PRINT),
        coverURL = coverURL,
        status = ReadingStatus.TO_READ,
        publisher = publisher,
        firstPublishedIn = firstPublishedIn,
        synopsis = synopsis,
        genre = genre,
        subgenres = subgenres,
        pageCount = pageCount,
        isbn13 = isbn13,
        language = language,
        series = series,
        narrators = narrators,
        durationMinutes = durationMinutes,
    )

    companion object {
        /** A release known only by what a list or a fixture says of it: nothing described yet. */
        fun listed(
            key: String,
            title: String,
            authors: List<String>,
            releaseFormat: ReleaseFormat,
            state: AwaitedState,
            originalTitle: String? = null,
            format: BookFormat? = null,
            language: BookLanguage? = null,
            originalLanguage: BookLanguage? = null,
            watched: Boolean = true,
            date: String? = null,
            isbn13: String? = null,
            coverURL: String? = null,
            storeURL: String? = null,
            series: SeriesMembership? = null,
        ) = Release(
            key = key,
            title = title,
            originalTitle = originalTitle ?: title,
            authors = authors,
            format = format ?: if (releaseFormat == ReleaseFormat.AUDIOBOOK) BookFormat.AUDIOBOOK else BookFormat.BOOK,
            releaseFormat = releaseFormat,
            language = language,
            originalLanguage = originalLanguage,
            state = state,
            watched = watched,
            date = date,
            isbn13 = isbn13,
            coverURL = coverURL,
            storeURL = storeURL,
            series = series,
        )
    }
}

/** The release as the server sends it, in every list and on every page. */
val ReleaseFields.asRelease: Release
    get() = Release(
        key = key,
        title = title,
        originalTitle = originalTitle,
        authors = authors,
        format = format.asDomain,
        releaseFormat = if (releaseFormat == GReleaseFormat.AUDIOBOOK) ReleaseFormat.AUDIOBOOK else ReleaseFormat.BOOK,
        language = language?.asDomain,
        originalLanguage = originalLanguage?.asDomain,
        state = when (state) {
            GAwaitedState.AVAILABLE -> AwaitedState.AVAILABLE
            GAwaitedState.ANNOUNCED -> AwaitedState.ANNOUNCED
            else -> AwaitedState.UNANNOUNCED
        },
        watched = watched,
        date = date,
        isbn13 = isbn13,
        coverURL = coverUrl,
        storeURL = storeUrl,
        series = series?.let { series -> series.seriesId?.let { SeriesMembership(it, series.name, series.volume, VolumeKind.MAIN) } },
        publisher = publisher,
        firstPublishedIn = firstPublishedIn,
        synopsis = synopsis,
        genre = genre?.asDomain,
        subgenres = subgenres,
        pageCount = pageCount,
        narrators = narrators,
        durationMinutes = durationMinutes,
        described = described,
    )

/** What a list showed a release as, which its page asks the server to describe. */
sealed interface ReleaseItem {
    data class AwaitedEdition(val id: String) : ReleaseItem
    data class AwardWinner(val key: String, val format: ReleaseFormat) : ReleaseItem
    data class Suggestion(val id: String, val format: ReleaseFormat) : ReleaseItem
    data class SagaVolume(val seriesId: String, val number: Int) : ReleaseItem
    data class Wish(val id: String) : ReleaseItem
}

private val ReleaseItem.input: ReleaseItemInput
    get() = when (this) {
        is ReleaseItem.AwaitedEdition -> ReleaseItemInput(awaitedEditionId = Optional.present(id))
        is ReleaseItem.AwardWinner -> ReleaseItemInput(awardWinner = Optional.present(AwardWinnerReleaseInput(format = format.graphQL, key = key)))
        is ReleaseItem.Suggestion -> ReleaseItemInput(suggestion = Optional.present(SuggestionReleaseInput(format = format.graphQL, id = id)))
        is ReleaseItem.SagaVolume -> ReleaseItemInput(sagaVolume = Optional.present(SagaVolumeReleaseInput(number = number, seriesId = seriesId)))
        is ReleaseItem.Wish -> ReleaseItemInput(wishId = Optional.present(id))
    }

/** The release's own requests: its description, and the covers any reader may pick for it. */
object ReleaseApi {
    /** The model looks the book up on the web the first time anybody opens it: about ten seconds. */
    suspend fun describe(item: ReleaseItem): Release =
        GraphQLClient.perform(DescribeReleaseOfMutation(item.input), changesLibrary = false)
            .describeReleaseOf.releaseFields.asRelease

    /** The covers any reader may pick for the release, the one drawn now first. Free: no model call. */
    suspend fun coverChoices(key: String, drawn: String?): List<CoverChoice> =
        GraphQLClient.fetch(ReleaseCoverChoicesQuery(key, Optional.presentIfNotNull(drawn)))
            .releaseCoverChoices.mapNotNull { coverChoiceOf(it.source, it.url, it.current) }

    /** Draws the release with the cover picked, for every reader. Answers the cover now drawn. */
    suspend fun chooseCover(key: String, url: String): String =
        GraphQLClient.perform(ChooseReleaseCoverMutation(key, url)).chooseReleaseCover
}

/** What picking a cover for a book nobody here holds asks of the server. */
interface ReleaseCoverClient {
    suspend fun choices(key: String, drawn: String?): List<CoverChoice>

    /** Answers the cover now drawn, for every reader. */
    suspend fun choose(key: String, url: String): String

    companion object {
        val live: ReleaseCoverClient = object : ReleaseCoverClient {
            override suspend fun choices(key: String, drawn: String?) = ReleaseApi.coverChoices(key, drawn)
            override suspend fun choose(key: String, url: String) = ReleaseApi.chooseCover(key, url)
        }
        val preview: ReleaseCoverClient = object : ReleaseCoverClient {
            override suspend fun choices(key: String, drawn: String?) = CoverChoice.previews
            override suspend fun choose(key: String, url: String) = url
        }
    }
}
